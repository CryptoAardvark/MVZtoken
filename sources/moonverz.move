module moonverz::m_coin {
  use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
  use aptos_framework::object::{Self, Object};
  use aptos_framework::primary_fungible_store;
  use aptos_framework::function_info;
  use aptos_framework::dispatchable_fungible_asset;
  use std::error;
  use std::signer;
  use std::string::{Self, utf8};
  use std::option;

  ///Only fungible asset metadata owner can make change
  const ENOT_OWNER: u64 = 1;
  ///The Moon coin is paused.
  const EPAUSED: u64 = 2;
  ///Definition symbol for token.
  const ASSET_SYMBOL: vector<u8> = b"MVZ";


  #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
  ///Hook refs to control minting, transfer and burining of fungible assets
  struct ManagedFungibleAsset has key{
    mint_ref: MintRef,
    transfer_ref: TransferRef,
    burn_ref: BurnRef,
  }

  #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
  ///Globalstate to pause MVZ coin
  /// Optional
  struct State has key {
    paused: bool,
  }

  ///initialize metadata
  fun init_module(admin: &signer) {
    let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
    primary_fungible_store::create_primary_store_enabled_fungible_asset(
      constructor_ref,
      option::none(),
      utf8(b"moonverz"),/*Definition name*/
      utf8(b"MVZ"),/*Definition symbol*/
      8,/*Definition decimal*/
      utf8(b"https:://"), /*Definiton icon*/
      utf8(b"https:://"), /*Definiton project*/
    );

    ///Create mint/burn/transfer refs to allow creator to manage the fungible assets.
    let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
    let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
    let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
    let metadata_object_signer = object::generate_signer(constructor_ref);

    ///Change owner ManagedFungibleAssets
    move_to(
    &metadata_object_signer, 
    ManagedFungibleAsset { mint_ref, transfer_ref, burn_ref },
    );

    ///Change owner State
    move_to(
    &metadata_object_signer,
    State { paused:false, }
    );

    ///Override functon info
    let deposit = function_info::new_function_info(
      admin,
      string::utf8(b"m_coin"),
      string::utf8(b"deposit"),
    );

    let withdraw = function_info::new_function_info(
      admin,
      string::utf8(b"m_coin"),
      string::utf8(b"withdraw"),
    );

    ///change owner dispatchableassets
    dispatchable_fungible_asset::register_dispatch_functions(
      constructor_ref,
      option::some(withdraw),
      option::some(deposit),
      option::none(),
    )
  }


  #[view]
  //Get address of managed fungible asset
  public fun get_metadata(): Object<Metadata> {
    let asset_address =  object::create_object_address(&@moonverz, ASSET_SYMBOL); /*!!!module name*/
    object::address_to_object<Metadata>(asset_address)
  }

  ///Deposit function override
  public fun deposit<T: key>(
    store: Object<T>,
    mvz: FungibleAsset,
    transfer_ref: &TransferRef
  )acquires State {
    assert_not_paused();
    fungible_asset::deposit_with_ref(transfer_ref, store, mvz)
  }

  ///Withdraw function override
  public fun withdraw<T: key>(
    store: Object<T>,
    amount: u64,
    transfer_ref: &TransferRef
  ): FungibleAsset acquires State {
    assert_not_paused();
    fungible_asset::withdraw_with_ref(transfer_ref, store, amount)
  }

  ///mint>
  public entry fun mint(admin: &signer, to: address, amount: u64) acquires ManagedFungibleAsset {
    let asset = get_metadata();
    let managed_fungible_asset = authorized_borrow_refs(admin, asset);
    let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
    let moon = fungible_asset::mint(&managed_fungible_asset.mint_ref, amount);
    fungible_asset::deposit_with_ref(&managed_fungible_asset.transfer_ref, to_wallet, moon);
  }
  ///transfer
  public entry fun transfer(admin: &signer, from: address, to: address, amount: u64) acquires ManagedFungibleAsset{
    let asset = get_metadata();
    let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
    let from_wallet = primary_fungible_store::primary_store(from, asset);
    let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
    let moon = withdraw(from_wallet, amount, transfer_ref);
    deposit(to_wallet, moon, transfer_ref);
  }
  ///burn
  public entry fun burn(admin: &signer, from: address, amount: u64) acquires ManagedFungibleAsset{
    let asset = get_metadata();
    let burn_ref = &authorized_borrow_refs(admin, asset).burn_ref;
    let from_wallet = primary_fungible_store::ensure_primary_store_exists(from, asset);
    fungible_asset::burn_from(burn_ref, from_wallet, amount);
  }
  ///Freeze
  public entry fun freeze_account(admin: &signer, account: address) acquires ManagedFungibleAsset{
    let asset = get_metadata();
    let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
    let wallet = primary_fungible_store::ensure_primary_store_exists(account, asset);
    fungible_asset::set_frozen_flag(transfer_ref, wallet, true);
  }
  ///Unfreeze
  public entry fun unfreeze_account(admin: &signer, account: address) acquires ManagedFungibleAsset{
    let asset = get_metadata();
    let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
    let wallet = primary_fungible_store::ensure_primary_store_exists(account, asset);
    fungible_asset::set_frozen_flag(transfer_ref, wallet, false);
  }
  ///Pause
  public entry fun set_pause(pauser: &signer, paused: bool) acquires State{
    let asset = get_metadata();
    assert!(object::is_owner(asset, signer::address_of(pauser)), error::permission_denied(ENOT_OWNER));
    let state = borrow_global_mut<State>(object::create_object_address(&@moonverz, ASSET_SYMBOL));
    if(state.paused == paused) {return};
    state.paused = paused;
  }
  ///Assert is not paused
  fun assert_not_paused() acquires State{
    let state = borrow_global<State>(object::create_object_address(&@moonverz, ASSET_SYMBOL));
    assert!(!state.paused, EPAUSED);
  }
  ///validation borrow ref
  inline fun authorized_borrow_refs(
    owner: &signer,
    asset: Object<Metadata>,
  ): &ManagedFungibleAsset acquires ManagedFungibleAsset{
    assert!(object::is_owner(asset, signer::address_of(owner)), error::permission_denied(ENOT_OWNER));
    borrow_global<ManagedFungibleAsset>(object::object_address(&asset))
  }
  ///test code
  #[test(creator = @moonverz)]
  fun test_basic_flow(
    creator: &signer,
  )acquires ManagedFungibleAsset, State{
    init_module(creator);
    let creator_address = signer::adress_of(creator);
    let aaron_address = @0xface;

    mint(creator, creator_address, 100);
    let asset = get_metadata();
    assert!(primary_fungible_store::balance(creator_address, asset) == 100, 4);
    freeze_account(creator, creator_address);
    assert!(primary_fungible_store::is_frozen(creator_address, asset), 5);
    transfer(creator, creator_address, aaron_address, 10);
    assert!(primary_fungible_store::balance(arron_address, asset) == 10, 6);

    unfreeze_account(creator, creator_address);
    assert!(!primary_fungible_store::is_frozen(creator_address, asset), 7);
    burn(creator, creator_address, 90);
  }

  #[test(creator = @moonverz, aaron = @0xface)]
  #[expected_failure(abort_code = 0x5001, location = Self)]
  fun test_permission_denied(
    creator: &signer,
    aaron: &signer
  )acquires ManagedFungibleAsset{
    init_module(creator);
    let creator_address = signer::address_of(creator);
    mint(aaron, creator_address, 100);
  }

  #[test(creator = @moonverz)]
  #[expected_failure(abort_code = 2, location = Self)]
  fun test_paused(
    creator: &signer,
  ) acquires ManagedFungibleAsset, State {
    init_module(creator);
    let creator_address = signer::address_of(creator);
    mint(creator, creator_address, 100);
    set_pause(creator, true);
    transfer(creator, creator_address, @0xface, 10);

  }
}