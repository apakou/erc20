use starknet::ContractAddress;

#[starknet::interface]
pub trait ICustomERC20 <TContractState> {
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, 
        from: ContractAddress, 
        to: ContractAddress, 
        amount: u256
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn burn(ref self: TContractState, amount: u256) -> bool;
}

#[starknet::interface]
pub trait IERC20Events<TContractState> {
    fn Transfer(ref self: TContractState, from: ContractAddress, to: ContractAddress, value: u256);
    fn Approval(ref self: TContractState, owner: ContractAddress, spender: ContractAddress, value: u256);
}

#[starknet::contract]
pub mod CustmERC20Contract {
    use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess, Map};
    use starknet::{get_caller_address, ContractAddress};
    use core::num::traits::Zero;
    use super::ICustomERC20;

    #[storage]
    struct Storage {
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        total_supply: u256,
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
        Approval: Approval,
        Burned: Burned,
        Minted: Minted,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        spender: ContractAddress,
        value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Burned {
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    pub struct Minted {
        #[key]
        pub to: ContractAddress,
        pub amount: u256
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, 
        name: ByteArray, 
        symbol: ByteArray, 
        decimals: u8,
    ) {
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals)
    }

    #[abi(embed_v0)]
    impl CustomERC20Impl of ICustomERC20<ContractState> {
        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            assert!(!account.is_zero(), "Provided address should not be zero address.");
            self.balances.read(account)
        }

        fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();

            assert!(!caller.is_zero(), "Caller address should not be zero address.");
            assert!(!to.is_zero(), "to address should not be zero address.");
            assert!(amount > 0, "The amount provided should be gretter than 0");

            let caller_balance = self.balances.read(caller);
            assert!(caller_balance >= amount, "Insufficient amount.");

            self.balances.write(caller, caller_balance - amount);
            let to_balance = self.balances.read(to);
            self.balances.write(to, to_balance + amount);

            self.emit(Transfer { 
                from: caller, 
                to: to, 
                value: amount 
            });

            true
        }

        fn transfer_from(ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();

            assert!(!caller.is_zero(), "Caller address should not be zero address.");
            assert!(!from.is_zero(), "From address should not be zero address.");
            assert!(!to.is_zero(), "To address should not be zero address.");
            assert!(amount > 0, "The amount provided should be gretter than 0");

            let from_balance = self.balances.read(from);
            assert!(from_balance >= amount, "Insufficient balance.");

            let current_allowance = self.allowances.read((from, caller));
            assert!(current_allowance >= amount, "Insufficient allowance.");

            self.balances.write(from, from_balance - amount);
            let to_balance = self.balances.read(to);
            self.balances.write(to, to_balance + amount);

            self.allowances.write((from, caller), current_allowance - amount);

            self.emit(Transfer { 
                from: from, 
                to: to, 
                value: amount 
            });

            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();

            assert!(!caller.is_zero(), "Caller address should not be zero address.");
            assert!(!spender.is_zero(), "Spender address should not be zero address.");
            assert!(amount > 0, "Invalid amount");

            self.emit(Approval { 
                owner: caller, 
                spender: spender, 
                value: amount 
            });

            true
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            assert!(!owner.is_zero(), "Owner address should not be zero address.");
            assert!(!spender.is_zero(), "Spender address should not be zero address.");

            self.allowances.read((owner, spender))
        }

        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            assert!(!to.is_zero(), "To address should not be zero address.");
            assert!(amount > 0, "The amount should be gretter than 0");

            let to_balance = self.balances.read(to);
            self.balances.write(to, to_balance + amount);

            let current_total_supply = self.total_supply.read();
            self.total_supply.write(current_total_supply + amount);

            self.emit(Minted {
                to: to,
                amount: amount
            });

            true
        }

        fn burn(ref self: ContractState, amount: u256) -> bool {
            assert!(amount > 0, "The amount should be gretter than 0");

            let current_total_supply = self.total_supply.read();
            self.total_supply.write(current_total_supply - amount);

            self.emit(Burned {
                amount: amount
            });

            true
        }
    }
}