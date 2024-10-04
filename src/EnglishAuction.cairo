use starknet::ContractAddress;

#[starknet::interface]
trait IERC721<TContractState> {
    fn safe_transfer_from(ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn transfer_from(ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256);
}

#[starknet::interface]
trait IEnglishAuction<TContractState> {
    fn start(ref self: TContractState);
    fn bid(ref self: TContractState);
    fn withdraw(ref self: TContractState);
    fn end(ref self: TContractState);
}

#[starknet::contract]
mod EnglishAuction {
    use super::{ContractAddress, IERC721, IEnglishAuction};
    use starknet::{get_caller_address, get_contract_address, get_block_timestamp};
    use zeroable::Zeroable;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::contract_address_const;

    const ETH_CONTRACT_ADDRESS: felt252 =
        0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Start: Start,
        Bid: Bid,
        Withdraw: Withdraw,
        End: End,
    }

    #[derive(Drop, starknet::Event)]
    struct Start {}

    #[derive(Drop, starknet::Event)]
    struct Bid {
        #[key]
        sender: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        #[key]
        bidder: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct End {
        winner: ContractAddress,
        amount: u256,
    }

    #[storage]
    struct Storage {
        nft: IERC721Dispatcher,
        nft_id: u256,
        seller: ContractAddress,
        end_at: u64,
        started: bool,
        ended: bool,
        highest_bidder: ContractAddress,
        highest_bid: u256,
        bids: LegacyMap::<ContractAddress, u256>,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        nft_address: ContractAddress,
        nft_id: u256,
        starting_bid: u256
    ) {
        self.nft.write(IERC721Dispatcher { contract_address: nft_address });
        self.nft_id.write(nft_id);
        self.seller.write(get_caller_address());
        self.highest_bid.write(starting_bid);
    }

    #[abi(embed_v0)]
    impl EnglishAuctionImpl of IEnglishAuction<ContractState> {
        fn start(ref self: ContractState) {
            assert(!self.started.read(), "already started");
            assert(get_caller_address() == self.seller.read(), "not seller");

            self.nft.read().transfer_from(get_caller_address(), get_contract_address(), self.nft_id.read());
            self.started.write(true);
            self.end_at.write(get_block_timestamp() + 7 * 24 * 60 * 60); // 7 days

            self.emit(Start {});
        }

        fn bid(ref self: ContractState) {
            let caller = get_caller_address();
            let eth_amount = self.get_eth_amount();

            assert(self.started.read(), "not started");
            assert(get_block_timestamp() < self.end_at.read(), "ended");
            assert(eth_amount > self.highest_bid.read(), "value < highest");

            if !self.highest_bidder.read().is_zero() {
                let current_highest_bid = self.bids.read(self.highest_bidder.read());
                self.bids.write(self.highest_bidder.read(), current_highest_bid + self.highest_bid.read());
            }

            self.highest_bidder.write(caller);
            self.highest_bid.write(eth_amount);

            self.emit(Bid { sender: caller, amount: eth_amount });
        }

        fn withdraw(ref self: ContractState) {
            let caller = get_caller_address();
            let amount = self.bids.read(caller);
            self.bids.write(caller, 0);

            let eth_dispatcher = IERC20Dispatcher { contract_address: contract_address_const::<ETH_CONTRACT_ADDRESS>() };
            eth_dispatcher.transfer(caller, amount);

            self.emit(Withdraw { bidder: caller, amount });
        }

        fn end(ref self: ContractState) {
            assert(self.started.read(), "not started");
            assert(get_block_timestamp() >= self.end_at.read(), "not ended");
            assert(!self.ended.read(), "already ended");

            self.ended.write(true);
            if !self.highest_bidder.read().is_zero() {
                self.nft.read().safe_transfer_from(get_contract_address(), self.highest_bidder.read(), self.nft_id.read());
                let eth_dispatcher = IERC20Dispatcher { contract_address: contract_address_const::<ETH_CONTRACT_ADDRESS>() };
                eth_dispatcher.transfer(self.seller.read(), self.highest_bid.read());
            } else {
                self.nft.read().safe_transfer_from(get_contract_address(), self.seller.read(), self.nft_id.read());
            }

            self.emit(End { winner: self.highest_bidder.read(), amount: self.highest_bid.read() });
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn get_eth_amount(self: @ContractState) -> u256 {
            let eth_dispatcher = IERC20Dispatcher { contract_address: contract_address_const::<ETH_CONTRACT_ADDRESS>() };
            eth_dispatcher.balance_of(get_caller_address())
        }
    }
}