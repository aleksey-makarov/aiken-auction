use aiken/hash.{Blake2b_224, Blake2b_256, Hash, blake2b_256}
use aiken/transaction.{
  Input, NoDatum, Output, OutputReference, ScriptContext, Spend, Transaction,
  TransactionId, DatumHash, find_datum, find_input,
}
use aiken/transaction/credential.{VerificationKey, Address, VerificationKeyCredential, ScriptCredential}
use aiken/transaction/value.{PolicyId, AssetName, Value}
use aiken/time.{PosixTime}
use aiken/option
use aiken/dict
use aiken/builtin
use aiken/bytearray
use aiken/list

type PubKeyHash = Hash<Blake2b_224, VerificationKey>
type DataHash = Hash<Blake2b_256, Data>

// ---------------------------------------------------------------------

type Bid {
  bidOwner: PubKeyHash,
  value: Int,
}

type LotDatum {
  seller:     PubKeyHash,
  deadline:   PosixTime,
  minBid:     Int,
  currency:   PolicyId,
  token:      AssetName,
  highestBid: Option<Bid>,
}

type AuctionRedeemer {
  MakeBid(Bid)
  Close
}

validator {
  fn auction(
    data: LotDatum,
    redeemer: AuctionRedeemer,
    ctx: ScriptContext,
  ) -> Bool {

    expect Spend(ownOutputRef) = ctx.purpose
    expect Some(ownInput) = find_input(ctx.transaction.inputs, ownOutputRef)
    expect DatumHash(ownInputDatumHash) = ownInput.output.datum
    expect Some(ownInputDatumU) = find_datum([], ctx.transaction.datums, ownInputDatumHash)
    expect ownInputDatum : LotDatum = ownInputDatumU

    expect [ownOutput] = (
      let isOwnOutput = fn (o: Output) -> Bool { o.address == ownInput.output.address }
      ctx.transaction.outputs |> list.filter(isOwnOutput)
    )
    expect DatumHash(ownOutputDatumHash) = ownOutput.datum
    expect Some(ownOutputDatumU) = find_datum([], ctx.transaction.datums, ownOutputDatumHash)
    expect ownOutputDatum : LotDatum = ownOutputDatumU

    // ------------------------------------------------------------
    // Predicates
    // ------------------------------------------------------------

    let sufficientBid = fn (bid: Bid) -> Bool {
      when data.highestBid is {
        None         -> data.minBid <= bid.value
        Some(oldBid) -> oldBid.value < bid.value
      }
    }

    // FIXME: ownInputDatum == data
    let correctBidOutputDatum = fn (bid: Bid) -> Bool {
         ownInputDatum.seller     == ownOutputDatum.seller
      && ownInputDatum.deadline   == ownOutputDatum.deadline
      && ownInputDatum.minBid     == ownOutputDatum.minBid
      && ownInputDatum.currency   == ownOutputDatum.currency
      && ownInputDatum.token      == ownOutputDatum.token
      && Some(bid)                == ownOutputDatum.highestBid
    }

    let correctBidOutputValue = fn (bid: Int) -> Bool {
      // this does not work:
      // ownOutput.value == (value.from_lovelace(bid) |> value.add(data.currency, data.token, 1))

      let v = ownOutput.value

      list.length(value.flatten(v)) == 2
      && value.quantity_of(v, some_policy_id, some_asset_name) == 1
      && value.lovelace_of(v) == bid
    }

    let correctBidRefund =
      when data.highestBid is {
        None -> True
        Some(bid) -> {
          let outputs = ctx.transaction.outputs
          let f = fn (o: Output) -> Bool {
            when o.address.payment_credential is {
              VerificationKeyCredential(addr) -> addr
              ScriptCredential(addr) -> addr
            } == bid.bidOwner
          }
          expect [refundOutput] = outputs |> list.filter(f)
          value.lovelace_of(refundOutput.value) == bid.value
        }
      }

    let correctBidSlotRange = True

    let correctCloseSlotRange = True

    when redeemer is {
      MakeBid ( bid ) -> sufficientBid(bid)?
                      && correctBidOutputDatum(bid)?
                      && correctBidOutputValue(bid.value)?
                      && correctBidRefund?
                      && correctBidSlotRange

      Close           -> correctCloseSlotRange
    }
  }
}

// ---------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------

const my_pub_key_hash : PubKeyHash     = #"000000000000000000000000000000000000000000000000000000ff"
const some_pub_key_hash : PubKeyHash   = #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50"
const bidder_pub_key_hash : PubKeyHash = #"aabbccddeeff00000000000000000000000000000000000000000000"
const refund_pub_key_hash : PubKeyHash = #"00000000000000000000000000000000000000000000121212121212"
const seller_pub_key_hash : PubKeyHash = #"00000000000000000000000000000000000000000000343434343434"

const some_fee : Int = 1000

const some_policy_id = #"abcdef0123456789"
const some_asset_name = "asdf"

fn mk_value(ada: Int) -> Value {
  value.from_lovelace(ada) |> value.add(some_policy_id, some_asset_name, 1)
}

fn mk_lot_datum(maybeBid: Option<Bid>) -> LotDatum {
  LotDatum {
    seller:     my_pub_key_hash,
    deadline:   100,
    minBid:     100,
    currency:   some_policy_id,
    token:      some_asset_name,
    highestBid: maybeBid,
  }
}

fn mk_output_reference(i: Int) -> OutputReference {
  OutputReference { transaction_id: TransactionId("2d86702c"), output_index: i }
}

fn mk_context(t: Transaction) -> ScriptContext {
  let purpose = Spend(mk_output_reference(0))
  ScriptContext { purpose, transaction: t }
}

fn mk_transaction() -> Transaction {
  transaction.placeholder()
    |> fn(t) { Transaction { ..t, fee: value.from_lovelace(some_fee) } }
}

fn mk_hash(d: Data) -> DataHash {
  blake2b_256(builtin.serialise_data(d))
}

fn mk_output(address: PubKeyHash, value: Int, maybeDataHash: Option<DataHash>) -> Output {
    Output {
      address:
        Address {
          payment_credential: VerificationKeyCredential(address),
          stake_credential: None,
        },
      value: mk_value(value),
      datum: when maybeDataHash is {
          Some(hash) -> DatumHash(hash)
          None -> NoDatum
        },
      reference_script: None,
    }
}

fn to_data(d: LotDatum) -> Data {
  let aData: Data = d
  aData
}

// fn composition(g: fn (b) -> c, f: fn (a) -> b) -> fn (a) -> c {
//   fn (x) { g(f(x)) }
// }

// fn id(x: a) -> a { x }

// fn first (x: (a, b)) -> a { x.1st }

fn second(x: (a, b)) -> b { x.2nd }

fn add_input(p: Transaction, output_reference: Int, address: PubKeyHash, value: Int, maybeBid: Option<LotDatum>) -> Transaction {

  let maybeDataHash = maybeBid |> option.map(
    fn (x) { (x, mk_hash(to_data(x))) }
  )

  let output = mk_output(address, value, maybeDataHash |> option.map(second))

  let input = Input { output_reference: mk_output_reference(output_reference), output }

  let t = Transaction { ..p, inputs: [input, ..p.inputs] }

  when maybeDataHash is {
    Some((data, hash)) -> Transaction { ..t, datums: (p.datums |> dict.insert(key: hash, value: data, compare: bytearray.compare))}
    None -> t
  }
}

fn add_output(p: Transaction, address: PubKeyHash, value: Int, maybeBid: Option<LotDatum>) -> Transaction {

  let maybeDataHash = maybeBid |> option.map(
    fn (x) { (x, mk_hash(to_data(x))) }
  )

  let output = mk_output(address, value, maybeDataHash |> option.map(second))

  let t = Transaction { ..p, outputs: [output, ..p.outputs] }

  when maybeDataHash is {
    Some((data, hash)) -> Transaction { ..t, datums: (p.datums |> dict.insert(key: hash, value: data, compare: bytearray.compare))}
    None -> t
  }
}

fn mk_insufficient_bid_test(bid: Int, minBid: Int, highestBid: Option<Int>) -> Bool {

  let d = LotDatum {
    seller:     seller_pub_key_hash,
    deadline:   10,
    minBid:     minBid,
    currency:   some_policy_id,
    token:      some_asset_name,
    highestBid: when highestBid is {
      None -> None
      Some(v) -> Some( Bid { bidOwner: refund_pub_key_hash, value: v} )
    },
  }

  let dnew = LotDatum { ..d, highestBid: Some( Bid {bidOwner: bidder_pub_key_hash, value: bid} ) }

  let refund = highestBid |> option.or_else(42)

  auction(
    d,
    MakeBid (
      Bid {
        bidOwner: bidder_pub_key_hash,
        value: bid,
      }
    ),
    mk_context(
      mk_transaction() |> add_input(0, my_pub_key_hash, 100, Some(d))
                       |> add_input(1, some_pub_key_hash, 100, None)
                       |> add_output(some_pub_key_hash, 100, None)
                       |> add_output(refund_pub_key_hash, refund, None)
                       |> add_output(my_pub_key_hash, bid, Some(dnew))
    )
  )
}

test insufficient_bid_1() fail {
  mk_insufficient_bid_test(100, 1000, None)
}

test insufficient_bid_2() {
  mk_insufficient_bid_test(1000, 1000, None)
}

test insufficient_bid_3() {
  mk_insufficient_bid_test(1010, 1000, None)
}

test insufficient_bid_4() fail {
  mk_insufficient_bid_test(100, 1000, Some(2000))
}

test insufficient_bid_5() fail {
  mk_insufficient_bid_test(100, 1000, Some(2000))
}

test insufficient_bid_6() {
  mk_insufficient_bid_test(2020, 1000, Some(2000))
}

test test_mk_output_reference() {
  mk_output_reference(0) == mk_output_reference(0)
}

test test_mk_output_reference_1() fail {
  mk_output_reference(0) == mk_output_reference(1)
}

test test_add_input() {
  let ctx = mk_context(
    mk_transaction() |> add_input(0, my_pub_key_hash, 100, Some(mk_lot_datum(None)))
                     |> add_input(1, some_pub_key_hash, 100, None)
                     |> add_output(my_pub_key_hash, 100, None)
                     |> add_output(some_pub_key_hash, 100, Some(mk_lot_datum(None)))
  )

  expect Spend(ownOutputRef) = ctx.purpose
  ownOutputRef == mk_output_reference(0)
}

test test_add_input_2() {
  let ctx = mk_context(
    mk_transaction() |> add_input(0, my_pub_key_hash, 100, Some(mk_lot_datum(None)))
                     |> add_input(1, some_pub_key_hash, 100, None)
                     |> add_output(my_pub_key_hash, 100, None)
                     |> add_output(some_pub_key_hash, 100, Some(mk_lot_datum(None)))
  )

  let allOutputReferences = ctx.transaction.inputs |> list.map(fn (i: Input) { i.output_reference} )
  allOutputReferences == [mk_output_reference(1), mk_output_reference(0)]
}

fn mk_correct_bid_output_datum_test(b: Bid, iData: LotDatum, oData: Option<LotDatum>) -> Bool {
  auction(
    iData,
    MakeBid (b),
    mk_context(
      mk_transaction() |> add_input(0, my_pub_key_hash, 100, Some(iData))
                       |> add_input(1, some_pub_key_hash, 100, None)
                       |> add_output(refund_pub_key_hash, 1000, None)
                       |> add_output(some_pub_key_hash, 100, None)
                       |> add_output(my_pub_key_hash, 1010, oData)
    )
  )
}

test test_correct_bid_output_datum() {
    let bid = Bid(bidder_pub_key_hash, 1010)
    let d = LotDatum {
        seller:     seller_pub_key_hash,
        deadline:   10,
        minBid:     100,
        currency:   some_asset_name,
        token:      some_policy_id,
        highestBid: Some (Bid (refund_pub_key_hash, 1000)),
      }
    let dnew = LotDatum { ..d, highestBid: Some(bid) }
    mk_correct_bid_output_datum_test(bid, d, Some(dnew))
}

test test_correct_bid_output_datum_1() fail {
    let bid = Bid(bidder_pub_key_hash, 1010)
    let d = LotDatum {
        seller:     seller_pub_key_hash,
        deadline:   10,
        minBid:     100,
        currency:   some_asset_name,
        token:      some_policy_id,
        highestBid: Some (Bid (refund_pub_key_hash, 1000)),
      }
    let dnew = d
    mk_correct_bid_output_datum_test(bid, d, Some(dnew))
}

test test_correct_bid_output_datum_3() fail {
    let bid = Bid(seller_pub_key_hash, 1010)
    let d = LotDatum {
        seller:     bidder_pub_key_hash,
        deadline:   10,
        minBid:     100,
        currency:   some_asset_name,
        token:      some_policy_id,
        highestBid: Some (Bid (refund_pub_key_hash, 1000)),
      }
    mk_correct_bid_output_datum_test(bid, d, None)
}

test test_correct_bid_output_datum_4() fail {
    let bid = Bid(seller_pub_key_hash, 1010)
    let d = LotDatum {
        seller:     bidder_pub_key_hash,
        deadline:   10,
        minBid:     100,
        currency:   some_asset_name,
        token:      some_policy_id,
        highestBid: Some (Bid (refund_pub_key_hash, 1000)),
      }
    let dnew = LotDatum { ..d, highestBid: Some(bid), minBid: 101 }
    mk_correct_bid_output_datum_test(bid, d, Some(dnew))
}

test test_check_transaction_output() {
  let t = mk_transaction() |> add_input(0, my_pub_key_hash, 100, None)
                           |> add_input(1, some_pub_key_hash, 100, None)
                           |> add_output(my_pub_key_hash, 1010, None)

  expect [x] = t.outputs
  value.lovelace_of(x.value) == 1010
}

test test_check_transaction_output_1() {
  let t = mk_transaction() |> add_input(0, my_pub_key_hash, 100, None)
                           |> add_input(1, some_pub_key_hash, 100, None)
                           |> add_output(my_pub_key_hash, 1010, None)

  expect [x] = t.outputs
  value.quantity_of(x.value, some_policy_id, some_asset_name) == 1
}

fn mk_output_1(address: PubKeyHash, value: Value, maybeDataHash: Option<DataHash>) -> Output {
    Output {
      address:
        Address {
          payment_credential: VerificationKeyCredential(address),
          stake_credential: None,
        },
      value: value,
      datum: when maybeDataHash is {
          Some(hash) -> DatumHash(hash)
          None -> NoDatum
        },
      reference_script: None,
    }
}

fn add_output1(p: Transaction, address: PubKeyHash, value: Value, maybeBid: Option<LotDatum>) -> Transaction {

  let maybeDataHash = maybeBid |> option.map(
    fn (x) { (x, mk_hash(to_data(x))) }
  )

  let output = mk_output_1(address, value, maybeDataHash |> option.map(second))

  let t = Transaction { ..p, outputs: [output, ..p.outputs] }

  when maybeDataHash is {
    Some((data, hash)) -> Transaction { ..t, datums: (p.datums |> dict.insert(key: hash, value: data, compare: bytearray.compare))}
    None -> t
  }
}

test test_correct_bid_output_value() {
  let some_value = value.from_lovelace(100)
  let some_value_1000 = value.from_lovelace(1000)
  let mk_value_with_nft = fn (v: Int) {
    value.from_lovelace(v) |> value.add(some_policy_id, some_asset_name, 1)
  }
  let d = LotDatum {
      seller:     seller_pub_key_hash,
      deadline:   10,
      minBid:     100,
      currency:   some_asset_name,
      token:      some_policy_id,
      highestBid: Some (Bid (refund_pub_key_hash, 1000)),
    }
  let dnew = LotDatum { ..d, highestBid: Some (Bid (bidder_pub_key_hash, 1010))}
  let r = MakeBid (
    Bid {
      bidOwner: bidder_pub_key_hash,
      value: 1010,
    }
  )
  let c = mk_context(
    transaction.placeholder() |> add_input(0, my_pub_key_hash, 1000, Some(d))
                              |> add_input(1, some_pub_key_hash, 100, None)
                              |> add_output1(some_pub_key_hash, some_value, None)
                              |> add_output1(refund_pub_key_hash, some_value_1000, None)
                              |> add_output1(my_pub_key_hash, mk_value_with_nft(1010), Some(dnew))
  )
  auction(d, r, c)
}

// wrong lovelace value
test test_correct_bid_output_value_1() fail {
  let some_value = value.from_lovelace(100)
  let some_value_1000 = value.from_lovelace(1000)
  let mk_value_with_nft = fn (v: Int) {
    value.from_lovelace(v) |> value.add(some_policy_id, some_asset_name, 1)
  }
  let d = LotDatum {
      seller:     seller_pub_key_hash,
      deadline:   10,
      minBid:     100,
      currency:   some_asset_name,
      token:      some_policy_id,
      highestBid: Some (Bid (refund_pub_key_hash, 1000)),
    }
  let dnew = LotDatum { ..d, highestBid: Some (Bid (bidder_pub_key_hash, 1010))}
  let r = MakeBid (
    Bid {
      bidOwner: bidder_pub_key_hash,
      value: 1010,
    }
  )
  let c = mk_context(
    transaction.placeholder() |> add_input(0, my_pub_key_hash, 1000, Some(d))
                              |> add_input(1, some_pub_key_hash, 100, None)
                              |> add_output1(some_pub_key_hash, some_value, None)
                              |> add_output1(refund_pub_key_hash, some_value_1000, None)
                              |> add_output1(my_pub_key_hash, mk_value_with_nft(1000), Some(dnew))
  )
  auction(d, r, c)
}

// no nft
test test_correct_bid_output_value_2() fail {
  let some_value = value.from_lovelace(100)
  let some_value_1000 = value.from_lovelace(1000)
  let d = LotDatum {
      seller:     seller_pub_key_hash,
      deadline:   10,
      minBid:     100,
      currency:   some_asset_name,
      token:      some_policy_id,
      highestBid: Some (Bid (refund_pub_key_hash, 1000)),
    }
  let dnew = LotDatum { ..d, highestBid: Some (Bid (bidder_pub_key_hash, 1010))}
  let r = MakeBid (
    Bid {
      bidOwner: bidder_pub_key_hash,
      value: 1010,
    }
  )
  let c = mk_context(
    transaction.placeholder() |> add_input(0, my_pub_key_hash, 1000, Some(d))
                              |> add_input(1, some_pub_key_hash, 100, None)
                              |> add_output1(some_pub_key_hash, some_value, None)
                              |> add_output1(refund_pub_key_hash, some_value_1000, None)
                              |> add_output1(my_pub_key_hash, value.from_lovelace(1010), Some(dnew))
  )
  auction(d, r, c)
}

// wrong nft
test test_correct_bid_output_value_3() fail {
  let some_value = value.from_lovelace(100)
  let some_value_1000 = value.from_lovelace(1000)
  let mk_value_with_nft = fn (v: Int) {
    value.from_lovelace(v) |> value.add(some_policy_id, "wtf", 1)
  }
  let d = LotDatum {
      seller:     seller_pub_key_hash,
      deadline:   10,
      minBid:     100,
      currency:   some_asset_name,
      token:      some_policy_id,
      highestBid: Some (Bid (refund_pub_key_hash, 1000)),
    }
  let dnew = LotDatum { ..d, highestBid: Some (Bid (bidder_pub_key_hash, 1010))}
  let r = MakeBid (
    Bid {
      bidOwner: bidder_pub_key_hash,
      value: 1010,
    }
  )
  let c = mk_context(
    transaction.placeholder() |> add_input(0, my_pub_key_hash, 1000, Some(d))
                              |> add_input(1, some_pub_key_hash, 100, None)
                              |> add_output1(some_pub_key_hash, some_value, None)
                              |> add_output1(refund_pub_key_hash, some_value_1000, None)
                              |> add_output1(my_pub_key_hash, mk_value_with_nft(1010), Some(dnew))
  )
  auction(d, r, c)
}

// one more nft
test test_correct_bid_output_value_4() fail {
  let some_value = value.from_lovelace(100)
  let some_value_1000 = value.from_lovelace(1000)
  let mk_value_with_nft = fn (v: Int) {
    value.from_lovelace(v) |> value.add(some_policy_id, "wtf", 1)
                           |> value.add(some_policy_id, some_asset_name, 1)
  }
  let d = LotDatum {
      seller:     seller_pub_key_hash,
      deadline:   10,
      minBid:     100,
      currency:   some_asset_name,
      token:      some_policy_id,
      highestBid: Some (Bid (refund_pub_key_hash, 1000)),
    }
  let dnew = LotDatum { ..d, highestBid: Some (Bid (bidder_pub_key_hash, 1010))}
  let r = MakeBid (
    Bid {
      bidOwner: bidder_pub_key_hash,
      value: 1010,
    }
  )
  let c = mk_context(
    transaction.placeholder() |> add_input(0, my_pub_key_hash, 1000, Some(d))
                              |> add_input(1, some_pub_key_hash, 100, None)
                              |> add_output1(some_pub_key_hash, some_value, None)
                              |> add_output1(refund_pub_key_hash, some_value_1000, None)
                              |> add_output1(my_pub_key_hash, mk_value_with_nft(1010), Some(dnew))
  )
  auction(d, r, c)
}

// incorrect refund value
test test_correct_bid_refund_1() fail {
  let some_value = value.from_lovelace(100)
  let some_value_bad = value.from_lovelace(1001)
  let mk_value_with_nft = fn (v: Int) {
    value.from_lovelace(v) |> value.add(some_policy_id, some_asset_name, 1)
  }
  let d = LotDatum {
      seller:     seller_pub_key_hash,
      deadline:   10,
      minBid:     100,
      currency:   some_asset_name,
      token:      some_policy_id,
      highestBid: Some (Bid (refund_pub_key_hash, 1000)),
    }
  let dnew = LotDatum { ..d, highestBid: Some (Bid (bidder_pub_key_hash, 1010))}
  let r = MakeBid (
    Bid {
      bidOwner: bidder_pub_key_hash,
      value: 1010,
    }
  )
  let c = mk_context(
    transaction.placeholder() |> add_input(0, my_pub_key_hash, 1000, Some(d))
                              |> add_input(1, some_pub_key_hash, 100, None)
                              |> add_output1(some_pub_key_hash, some_value, None)
                              |> add_output1(refund_pub_key_hash, some_value_bad, None)
                              |> add_output1(my_pub_key_hash, mk_value_with_nft(1010), Some(dnew))
  )
  auction(d, r, c)
}

// no refund address
test test_correct_bid_refund_2() fail {
  let some_value = value.from_lovelace(100)
  let mk_value_with_nft = fn (v: Int) {
    value.from_lovelace(v) |> value.add(some_policy_id, some_asset_name, 1)
  }
  let d = LotDatum {
      seller:     seller_pub_key_hash,
      deadline:   10,
      minBid:     100,
      currency:   some_asset_name,
      token:      some_policy_id,
      highestBid: Some (Bid (refund_pub_key_hash, 1000)),
    }
  let dnew = LotDatum { ..d, highestBid: Some (Bid (bidder_pub_key_hash, 1010))}
  let r = MakeBid (
    Bid {
      bidOwner: bidder_pub_key_hash,
      value: 1010,
    }
  )
  let c = mk_context(
    transaction.placeholder() |> add_input(0, my_pub_key_hash, 1000, Some(d))
                              |> add_input(1, some_pub_key_hash, 100, None)
                              |> add_output1(some_pub_key_hash, some_value, None)
                              |> add_output1(my_pub_key_hash, mk_value_with_nft(1010), Some(dnew))
  )
  auction(d, r, c)
}
