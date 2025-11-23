use snforge_std::CheatSpan;
use core::array;
use snforge_std::DeclareResultTrait;
use starknet::contract_address_const;
use snforge_std::{declare, ContractClassTrait, cheat_account_contract_address, spy_events, EventSpyAssertionsTrait};
use contracts::custom_erc20::{ICustomERC20Dispatcher, ICustomERC20DispatcherTrait};
use contracts::custom_erc20::CustmERC20Contract::{Minted, Event};

fn deploy_contract() -> ICustomERC20Dispatcher {
     let contract = declare("CustmERC20Contract").unwrap().contract_class();

    let mut constructor_args = array![];
    let name: ByteArray = "ImprenableToken";
    let symbol: ByteArray = "IMPT";
    let decimals: u8 = 18;

    name.serialize(ref constructor_args);
    symbol.serialize(ref constructor_args);
    decimals.serialize(ref constructor_args);

    let (contract_address, _) = contract.deploy(@constructor_args).unwrap();

    let dispatcher = ICustomERC20Dispatcher{contract_address};

    return dispatcher;
}
#[test]
fn test_contract_initialization() {
   let dispatcher = deploy_contract();
    
    let total_supply = dispatcher.total_supply();
    let expected_total_supply = 0;

    
    assert!(total_supply == expected_total_supply, "Total supply does not match expected value");
}

#[test]
#[should_panic(expected: "Provided address should not be zero address.")]
fn test_balance_of_zero_address() {
    let dispatcher = deploy_contract();

    let zero_address = contract_address_const::<0>();
    dispatcher.balance_of(zero_address);
}


#[test]
fn test_balance_of_address() {
    let dispatcher = deploy_contract();

    let user_address = contract_address_const::<'user1'>();
    cheat_account_contract_address(dispatcher.contract_address, user_address, CheatSpan::TargetCalls(1));

    let user_balance = dispatcher.balance_of(user_address);
    let expected_balance = 0;

    assert!(user_balance == expected_balance, "User balance does not match expected value");
}

#[test]
#[should_panic(expected: "The amount should be gretter than 0")]
fn test_mint() {
    let dispatcher = deploy_contract();

    let user_address = contract_address_const::<'user1'>();
    let amount = 0;

    let mut spy = spy_events();

    let result = dispatcher.mint(user_address, amount);

    let expected_event = Minted{ to: user_address, amount: amount };

    spy.assert_emitted(
        @array![
            (dispatcher.contract_address, Event::Minted(expected_event))
        ]
    );

    assert!(result == true, "Minting failed");
}