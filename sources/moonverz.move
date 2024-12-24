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
  struct ManagedFungibleAssets has key{
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
    ManagedFungibleAssets { mint_ref, transfer_ref, burn_ref },
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

  

}