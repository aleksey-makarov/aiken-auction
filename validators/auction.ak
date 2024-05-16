use aiken/hash.{Blake2b_224, Blake2b_256, Hash, blake2b_256}
use aiken/transaction.{
  Input, NoDatum, Output, OutputReference, ScriptContext, Spend, Transaction,
  TransactionId, DatumHash, find_datum, find_input,
}
use aiken/transaction/credential.{VerificationKey, Address, VerificationKeyCredential}
use aiken/transaction/value.{PolicyId, AssetName}
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

    let correctBidOutputDatum = fn (bid: Bid) -> Bool {
         ownInputDatum.seller     == ownOutputDatum.seller
      && ownInputDatum.deadline   == ownOutputDatum.deadline
      && ownInputDatum.minBid     == ownOutputDatum.minBid
      && ownInputDatum.currency   == ownOutputDatum.currency
      && ownInputDatum.token      == ownOutputDatum.token
      && Some(bid)                == ownOutputDatum.highestBid
    }

    let correctBidOutputValue = True

    let correctBidRefund = True

    let correctBidSlotRange = True

    let correctCloseSlotRange = True

    when redeemer is {
      MakeBid ( bid ) -> sufficientBid(bid)?
                      && correctBidOutputDatum(bid)?
                      && correctBidOutputValue
                      && correctBidRefund
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

const some_fee : Int = 1000

fn mk_lot_datum(maybeBid: Option<Bid>) -> LotDatum {
  LotDatum {
    seller:     my_pub_key_hash,
    deadline:   100,
    minBid:     100,
    currency:   #"",
    token:      "asdf",
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
      value: value.from_lovelace(value),
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

  let mk_datum = fn (hb: Option<Int>) {
    let mk_bid = fn (v: Int) -> Bid {
      Bid(bidder_pub_key_hash, v)
    }
    LotDatum {
      seller:     bidder_pub_key_hash,
      deadline:   10,
      minBid:     minBid,
      currency:   some_pub_key_hash,
      token:      "asdf",
      highestBid: hb |> option.map(mk_bid),
    }
  }

  let d = mk_datum(highestBid)

  let dnew = mk_datum(Some(bid))

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
                       |> add_output(my_pub_key_hash, 100, Some(dnew))
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
                       |> add_output(some_pub_key_hash, 100, None)
                       |> add_output(my_pub_key_hash, 100, oData)
    )
  )
}

test test_correct_bid_output_datum() {
    let bid = Bid(bidder_pub_key_hash, 1010)
    let d = LotDatum {
        seller:     bidder_pub_key_hash,
        deadline:   10,
        minBid:     100,
        currency:   some_pub_key_hash,
        token:      "asdf",
        highestBid: Some (Bid (bidder_pub_key_hash, 1000)),
      }
    let dnew = LotDatum { ..d, highestBid: Some(bid) }
    mk_correct_bid_output_datum_test(bid, d, Some(dnew))
}

test test_correct_bid_output_datum_1() fail {
    let bid = Bid(bidder_pub_key_hash, 1010)
    let d = LotDatum {
        seller:     bidder_pub_key_hash,
        deadline:   10,
        minBid:     100,
        currency:   some_pub_key_hash,
        token:      "asdf",
        highestBid: Some (Bid (bidder_pub_key_hash, 1000)),
      }
    let dnew = d
    mk_correct_bid_output_datum_test(bid, d, Some(dnew))
}

test test_correct_bid_output_datum_3() fail {
    let bid = Bid(bidder_pub_key_hash, 1010)
    let d = LotDatum {
        seller:     bidder_pub_key_hash,
        deadline:   10,
        minBid:     100,
        currency:   some_pub_key_hash,
        token:      "asdf",
        highestBid: Some (Bid (bidder_pub_key_hash, 1000)),
      }
    mk_correct_bid_output_datum_test(bid, d, None)
}

test test_correct_bid_output_datum_4() fail {
    let bid = Bid(bidder_pub_key_hash, 1010)
    let d = LotDatum {
        seller:     bidder_pub_key_hash,
        deadline:   10,
        minBid:     100,
        currency:   some_pub_key_hash,
        token:      "asdf",
        highestBid: Some (Bid (bidder_pub_key_hash, 1000)),
      }
    let dnew = LotDatum { ..d, highestBid: Some(bid), minBid: 101 }
    mk_correct_bid_output_datum_test(bid, d, Some(dnew))
}
