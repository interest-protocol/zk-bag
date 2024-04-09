/// Module: zk-bag
module zk_bag::zk_bag {
  // === Imports ===

 use sui::transfer::Receiving;
 use sui::table::{Self, Table};
 use sui::vec_set::{Self, VecSet};

  // === Friends ===

  // === Errors ===

  const EZKBagAlreadyCreated: u64 = 0;
  const ENoZKBagFound: u64 = 1;
  const EInvalidOwner: u64 = 2;
  const EInvalidSetLength: u64 = 4;
  const EReceiverNotFound: u64 = 5;
  const EReceiverAlreadyAdded: u64 = 6;
  const EInvalidClaim: u64 = 7;
  const ENotAllowedToClaim: u64 = 8;
  const EThereAreItemsLeftToClaim: u64 = 9;

  // === Constants ===

  const MAX_SET_LENGTH: u64 = 500;

  // === Structs ===

 public struct ZkBag has key, store {
  id: UID,
  owner: address,
  item_ids: VecSet<address>
 }

 public struct BagClaim {
  bag_id: ID
 }

 public struct BagStore has key {
  id: UID,
  items: Table<address, ZkBag>
 }

  // === Public-Mutative Functions ===

 fun init(ctx: &mut TxContext) {
  let bag_store = BagStore {
   id: object::new(ctx),
   items: table::new(ctx)
  };

  transfer::share_object(bag_store);
 }

 public fun new(self:&mut BagStore, receiver: address, ctx: &mut TxContext) {
  assert!(!table::contains(&self.items, receiver), EZKBagAlreadyCreated);

  let zk_bag = ZkBag {
   id: object::new(ctx),
   owner: tx_context::sender(ctx),
   item_ids: vec_set::empty()
  };

  table::add(&mut self.items, receiver, zk_bag);
 }

 public fun add<Item: store + key>(self: &mut BagStore, receiver: address, item: Item, ctx: &mut TxContext) {
  assert!(table::contains(&self.items, receiver), ENoZKBagFound);

  let zk_bag = table::borrow_mut(&mut self.items, receiver);

  assert!(zk_bag.owner == tx_context::sender(ctx), EInvalidOwner); 

  assert!(MAX_SET_LENGTH > vec_set::size(&zk_bag.item_ids), EInvalidSetLength);

  vec_set::insert(&mut zk_bag.item_ids, object::id_address(&item));

  transfer::public_transfer(item, object::id_address(zk_bag))
 }

 public fun init_claim(self: &mut BagStore, ctx: &mut TxContext): (ZkBag, BagClaim) {
  let sender = tx_context::sender(ctx);

  assert!(table::contains(&self.items, sender), ENoZKBagFound);

  let zk_bag = table::remove(&mut self.items, sender);

  let bag_id = object::id(&zk_bag);

  (zk_bag, BagClaim { bag_id })
 }

 public fun reclaim(self: &mut BagStore, receiver: address, ctx: &mut TxContext): (ZkBag, BagClaim) {
  assert!(table::contains(&self.items, receiver), ENoZKBagFound);

  let zk_bag = table::borrow_mut(&mut self.items, receiver);

  assert!(zk_bag.owner == tx_context::sender(ctx), EInvalidOwner); 

  let zk_bag = table::remove(&mut self.items, receiver);

  let bag_id = object::id(&zk_bag);

  (zk_bag, BagClaim { bag_id })
 }

 public fun update_receiver(self: &mut BagStore, receiver: address, new_receiver: address, ctx: &mut TxContext) {
  assert!(table::contains(&self.items, receiver), ENoZKBagFound);

  let zk_bag = table::borrow(&self.items, receiver);

  assert!(vec_set::contains(&zk_bag.item_ids, &receiver), EReceiverNotFound);
  assert!(!vec_set::contains(&zk_bag.item_ids, &new_receiver), EReceiverNotFound);   

  let zk_bag = table::remove(&mut self.items, receiver);

  assert!(zk_bag.owner == tx_context::sender(ctx), EReceiverAlreadyAdded); 

  table::add(&mut self.items, new_receiver, zk_bag);
 }

 public fun claim<Item: store + key>(zk_bag: &mut ZkBag, claim: &BagClaim, item_receiving: Receiving<Item>): Item {
  assert!(is_valid_claim_object(zk_bag, claim), EInvalidClaim);

  let item = transfer::public_receive(&mut zk_bag.id, item_receiving);

  let item_address = object::id_address(&item);

  assert!(vec_set::contains(&zk_bag.item_ids, &item_address), ENotAllowedToClaim);

  vec_set::remove(&mut zk_bag.item_ids, &item_address);

  item
 }

 public fun finalize(zk_bag: ZkBag, claim: BagClaim) {
  assert!(is_valid_claim_object(&zk_bag, &claim), EInvalidClaim);

  assert!(vec_set::size(&zk_bag.item_ids) == 0, EThereAreItemsLeftToClaim);

  let BagClaim { bag_id: _ } = claim;

  let ZkBag { id, owner: _, item_ids: _ } = zk_bag;

  object::delete(id);
 }

  // === Public-View Functions ===

  // === Admin Functions ===

  // === Public-Friend Functions ===

  // === Private Functions ===

  fun is_valid_claim_object(zk_bag: &ZkBag, claim: &BagClaim): bool {
   object::id(zk_bag) == claim.bag_id
  }
}