use core::starknet::ContractAddress;
#[starknet::interface]

trait IDeAuction<TContractState> {
    // fn set_item_id(ref self: TContractState, item_id: felt252);
    // fn get_balance(self: @TContractState) -> felt252;

    fn safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: felt252
    );
    fn start(ref self: TContractState);
    fn bid(ref self: TContractState, sender: ContractAddress, amount: felt252);
    fn withdraw(ref self: TContractState, bidder: ContractAddress, amount: felt252);
    fn end(ref self: TContractState, winner: ContractAddress, amount: felt252);
}

#[starknet::contract]
mod DeAuctionAuctioner {
    use core::starknet::storage::{Map, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        started: bool,
        ended: bool,
        bids: Map::<ContractState, felt252>,
        nft: starknet::ContractAddress,
        nft_id: felt252,
        starting_bid: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, nft: starknet::ContractAddress, nft_id: felt252, starting_bid: felt252) {
        self.started.write(true);
        self.ended.write(false);
        self.nft.write(nft);
        self.nft_id.write(nft_id);
        self.starting_bid.write(starting_bid);
    }

    #[abi(embed_v0)]
    // to do
    impl DeAuctionImpl of super::IDeAuction<ContractState> {
        // fn set_item_id(ref self: ContractState, item_id: felt252) {
        //     assert(item_id != 0, 'Amount cannot be 0');
        //     self.item_id.write(item_id);
        // }

        // fn get_balance(self: @ContractState) -> felt252 {
        //     self.balance.read()
        // }
        fn start(ref self: ContractState) {
            // nft.transferFrom(msg.sender, address(this), nftId);
            self.started.write(true);
            endAt = block.timestamp + 7 days;
    
            emit Start();
        }
    }
}
