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
  struct ManagedFungibleAssets {
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


  

}