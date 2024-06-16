use aiken/hash.{Blake2b_224, Blake2b_256, Hash, blake2b_256}
use aiken/transaction.{
  Input, NoDatum, Output, OutputReference, ScriptContext, Spend, Transaction,
  TransactionId, DatumHash, ValidityRange, find_input,
}
use aiken/transaction/credential.{VerificationKey, Address, VerificationKeyCredential, ScriptCredential}
use aiken/transaction/value.{PolicyId, AssetName, Value, ada_asset_name, ada_policy_id}
use aiken/time.{PosixTime}
use aiken/option
use aiken/dict
use aiken/builtin
use aiken/bytearray
use aiken/list
use aiken/interval

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
  policy_id:  PolicyId,
  asset_name: AssetName,
  highestBid: Option<Bid>,
}

type AuctionRedeemer {
  MakeBid(Bid) // FIXME: no need to have bid here: just check new data against old one
  Close
}

fn print_data_hashes(lba: List<ByteArray>) -> Void {
  when lba is {
    [] -> Void
    [x, ..xs] -> {
      print_data_hashes(builtin.debug(bytearray.to_hex(x), xs))
    }
  }
}

validator {
  fn auction(
    data: LotDatum,
    redeemer: AuctionRedeemer,
    ctx: ScriptContext,
  ) -> Bool {

    expect Spend(ownOutputRef) = ctx.purpose
    expect Some(ownInput) = find_input(ctx.transaction.inputs, ownOutputRef)

    let getOwnOutput = fn () -> Output {
      expect [ownOutput] = (
        let isOwnOutput = fn (o: Output) -> Bool { o.address == ownInput.output.address }
        ctx.transaction.outputs |> list.filter(isOwnOutput)
      )
      ownOutput
    }

    let sufficientBid = fn (bid: Bid) -> Bool {
      when data.highestBid is {
        None         -> data.minBid <= bid.value
        Some(oldBid) -> oldBid.value < bid.value
      }
    }

    let correctBidOutputDatum = fn (bid: Bid) -> Bool {

      print_data_hashes(dict.keys(ctx.transaction.datums))

      expect DatumHash(ownOutputDatumHash) = getOwnOutput().datum
      expect Some(ownOutputDatumUntyped) = dict.get(ctx.transaction.datums, ownOutputDatumHash)
      expect ownOutputDatum : LotDatum = ownOutputDatumUntyped

         data.seller     == ownOutputDatum.seller
      && data.deadline   == ownOutputDatum.deadline
      && data.minBid     == ownOutputDatum.minBid
      && data.policy_id  == ownOutputDatum.policy_id
      && data.asset_name == ownOutputDatum.asset_name
      && Some(bid)       == ownOutputDatum.highestBid
    }

    let correctBidOutputValue = fn (bid: Int) -> Bool {
      getOwnOutput().value == (value.from_lovelace(bid) |> value.add(data.policy_id, data.asset_name, 1))
    }

    let correctBidRefund = fn () -> Bool {
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
    }

    let correctBidSlotRange = fn () -> Bool {
      interval.is_entirely_before(ctx.transaction.validity_range, data.deadline)
    }

    let correctCloseSlotRange = fn () -> Bool {
      interval.is_entirely_after(ctx.transaction.validity_range, data.deadline)
    }

    let getValueSentToAddress = fn (address: PubKeyHash, policy_id: PolicyId, asset_name: AssetName) -> Int {
      let f = fn (o: Output, i: Int) -> Int {
        if o.address.payment_credential == VerificationKeyCredential(address) {
          i + value.quantity_of(o.value, policy_id, asset_name)
        } else {
          i
        }
      }
      list.foldr(ctx.transaction.outputs, 0, f)
    }

    let sellerGetsToken = fn () -> Bool {
      getValueSentToAddress(data.seller, data.policy_id, data.asset_name) >= 1
    }

    let highestBidderGetsToken = fn (bid: Bid) -> Bool {
      getValueSentToAddress(bid.bidOwner, data.policy_id, data.asset_name) >= 1
    }

    let sellerGetsHighestBid = fn (bid: Bid) -> Bool {
      getValueSentToAddress(data.seller, ada_policy_id, ada_asset_name) >= bid.value
    }

    let correctClose = fn () -> Bool {
      when data.highestBid is {
        None      ->    sellerGetsToken()?

        Some(bid) ->    highestBidderGetsToken(bid)?
                     && sellerGetsHighestBid(bid)?
      }
    }

    when redeemer is {
      MakeBid ( bid ) ->    sufficientBid(bid)?
                         && correctBidOutputDatum(bid)?
                         && correctBidOutputValue(bid.value)?
                         && correctBidRefund()?
                         && correctBidSlotRange()?

      Close           ->    correctClose()
                         && correctCloseSlotRange()?
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

const some_policy_id = #"abcdef0123456789"
const some_asset_name = "asdf"

fn mk_output_reference(i: Int) -> OutputReference {
  OutputReference { transaction_id: TransactionId("2d86702c"), output_index: i }
}

fn mk_context(t: Transaction) -> ScriptContext {
  let purpose = Spend(mk_output_reference(0))
  ScriptContext { purpose, transaction: t }
}

fn mk_value_with_nft(v: Int) -> Value {
  value.from_lovelace(v) |> value.add(some_policy_id, some_asset_name, 1)
}

fn mk_output(address: PubKeyHash, value: Value, maybeDataHash: Option<DataHash>) -> Output {
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

fn mk_lot_datum_hash(d: LotDatum) -> DataHash {
  let aData: Data = d
  blake2b_256(builtin.serialise_data(aData))
}

// fn composition(g: fn (b) -> c, f: fn (a) -> b) -> fn (a) -> c {
//   fn (x) { g(f(x)) }
// }

fn id(x: a) -> a { x }

// fn first (x: (a, b)) -> a { x.1st }

fn second(x: (a, b)) -> b { x.2nd }

fn add_input(p: Transaction, output_reference: Int, address: PubKeyHash, value: Value, maybeBid: Option<LotDatum>) -> Transaction {

  let maybeDataHash = maybeBid |> option.map(
    fn (x) { (x, mk_lot_datum_hash(x)) }
  )

  let output = mk_output(address, value, maybeDataHash |> option.map(second))

  let input = Input { output_reference: mk_output_reference(output_reference), output }

  let t = Transaction { ..p, inputs: [input, ..p.inputs] }

  when maybeDataHash is {
    Some((data, hash)) -> Transaction { ..t, datums: (p.datums |> dict.insert(key: hash, value: data, compare: bytearray.compare))}
    None -> t
  }
}

fn add_output(p: Transaction, address: PubKeyHash, value: Value, maybeBid: Option<LotDatum>) -> Transaction {

  let maybeDataHash = maybeBid |> option.map(
    fn (x) { (x, mk_lot_datum_hash(x)) }
  )

  let output = mk_output(address, value, maybeDataHash |> option.map(second))

  let t = Transaction { ..p, outputs: [output, ..p.outputs] }

  when maybeDataHash is {
    Some((data, hash)) -> Transaction { ..t, datums: (p.datums |> dict.insert(key: hash, value: data, compare: bytearray.compare))}
    None -> t
  }
}

type InputGen {
  tx: Int,
  address: PubKeyHash,
  value: Value,
  datum: Option<LotDatum>,
}

type OutputGen {
  address: PubKeyHash,
  value: Value,
  datum: Option<LotDatum>,
}

type Alt<a> = fn (a) -> a

fn mk_transaction(il: List<InputGen>, ol: List<OutputGen>) -> Transaction {

  let fni = fn (i: InputGen, t: Transaction) -> Transaction {
    add_input(t, i.tx, i.address, i.value, i.datum)
  }

  let t1 = list.foldl(il, transaction.placeholder(), fni)

  let fno = fn (i: OutputGen, t: Transaction) -> Transaction {
    add_output(t, i.address, i.value, i.datum)
  }

  list.foldl(ol, t1, fno)
}

fn run_test_make_bid(
  first: Bool,
  fixDatum: Alt<LotDatum>,
  fixRedeemer: Alt<AuctionRedeemer>,
  fixInputs: Alt<List<InputGen>>,
  fixOuputs: Alt<List<OutputGen>>,
  fixTransaction: Alt<Transaction>,
  auc: fn (LotDatum, AuctionRedeemer, ScriptContext) -> Bool,
) -> Bool {

  let bid = 1010

  let d = LotDatum {
    seller:     seller_pub_key_hash,
    deadline:   10000,
    minBid:     100,
    policy_id:  some_policy_id,
    asset_name: some_asset_name,
    highestBid: if first { None } else { Some (Bid (refund_pub_key_hash, 1000)) },
  }

  let dnew = LotDatum { ..d, highestBid: Some (Bid (bidder_pub_key_hash, bid))}

  let r = MakeBid (
    Bid {
      bidOwner: bidder_pub_key_hash,
      value: bid,
    }
  )

  let inputs = [
    InputGen { tx: 0, address: my_pub_key_hash, value: mk_value_with_nft(1000), datum: Some(d) },
    InputGen { tx: 1, address: some_pub_key_hash, value: value.from_lovelace(100), datum: None },
  ]

  let outputs1 = [
    OutputGen { address: some_pub_key_hash, value: value.from_lovelace(100), datum: None },
    OutputGen { address: my_pub_key_hash, value: mk_value_with_nft(1010), datum: Some(dnew) },
  ]

  let refund_output = OutputGen { address: refund_pub_key_hash, value: value.from_lovelace(1000), datum: None }

  let outputs = if first { outputs1 } else { [ refund_output, ..outputs1 ] }

  let t = Transaction { ..mk_transaction(fixInputs(inputs), fixOuputs(outputs)), validity_range: interval.entirely_before(9000) }

  auc(fixDatum(d), fixRedeemer(r), mk_context(fixTransaction(t)))
}

test test_run_make_bid_first() {
  run_test_make_bid(True, id, id, id, id, id, auction)
}

test test_run_make_bid() {
  run_test_make_bid(False, id, id, id, id, id, auction)
}

fn fixRedeemerBid(r: AuctionRedeemer, bid: Int) -> AuctionRedeemer {
  when r is {
    MakeBid(b) -> MakeBid(Bid { ..b, value: bid } )
    _ -> r
  }
}

fn fixDatum(d: LotDatum, v: Int) -> LotDatum {
  let newHighestBid = when d.highestBid is {
    None -> None
    Some(b) -> Some(Bid { ..b, value: v } )
  }
  LotDatum { ..d, highestBid: newHighestBid }
}

fn fixOutputAddress(ol: List<OutputGen>, address: PubKeyHash, v: Int) -> List<OutputGen> {
  let o <- list.map(ol, _)
  if o.address == address {
    let value = value.from_lovelace(v) |> value.add(some_policy_id, some_asset_name, 1)
    OutputGen {..o, value: value, datum: option.map(o.datum, fixDatum(_, v))}
  } else {
    o
  }
}

// first bid is too small
test test_sufficient_bid_1() fail {
  run_test_make_bid(True, id, fixRedeemerBid(_, 90), id, fixOutputAddress(_, my_pub_key_hash, 90), id, auction)
}

// first bid is ok (but minimal)
test test_sufficient_bid_2() {
  run_test_make_bid(True, id, fixRedeemerBid(_, 100), id, fixOutputAddress(_, my_pub_key_hash, 100), id, auction)
}

// first bid is ok (quite big)
test test_sufficient_bid_3() {
  run_test_make_bid(True, id, fixRedeemerBid(_, 1000), id, fixOutputAddress(_, my_pub_key_hash, 1000), id, auction)
}

// next bid is too small
test test_sufficient_bid_4() fail {
  run_test_make_bid(False, id, fixRedeemerBid(_, 90), id, fixOutputAddress(_, my_pub_key_hash, 90), id, auction)
}

// next  bid is equal to previous
test test_sufficient_bid_5() fail {
  run_test_make_bid(False, id, fixRedeemerBid(_, 1000), id, fixOutputAddress(_, my_pub_key_hash, 1000), id, auction)
}

// next bid is ok (quite big)
test test_sufficient_bid_6() {
  run_test_make_bid(False, id, fixRedeemerBid(_, 1010), id, fixOutputAddress(_, my_pub_key_hash, 1010), id, auction)
}

test test_mk_output_reference() {
  mk_output_reference(0) == mk_output_reference(0)
}

test test_mk_output_reference_1() fail {
  mk_output_reference(0) == mk_output_reference(1)
}

test test_add_input() {
  let auction1 = fn (
    _: LotDatum,
    _: AuctionRedeemer,
    ctx: ScriptContext,
  ) {
    expect Spend(ownOutputRef) = ctx.purpose
    ownOutputRef == mk_output_reference(0)
  }
  run_test_make_bid(False, id, id, id, id, id, auction1)
}

test test_add_input_2() {
  let auction1 = fn (
    _: LotDatum,
    _: AuctionRedeemer,
    ctx: ScriptContext,
  ) {
    let allOutputReferences = ctx.transaction.inputs |> list.map(fn (i: Input) { i.output_reference } )
    allOutputReferences == [mk_output_reference(1), mk_output_reference(0)]
  }
  run_test_make_bid(False, id, id, id, id, id, auction1)
}

fn fixOutputAddressDatum(ol: List<OutputGen>, address: PubKeyHash, f: fn (LotDatum) -> LotDatum) -> List<OutputGen> {
  let fmap = fn (o: OutputGen) -> OutputGen {
    if o.address == address {
      OutputGen {..o, datum: o.datum |> option.map(f) }
    } else { o }
  }
  ol |> list.map(fmap)
}

// highest bid does no equal to the bid
test test_correct_bid_output_datum_1() fail {
  let f = fn (d: LotDatum) -> LotDatum {
    when d.highestBid is {
      None -> d
      Some(b) -> {
        LotDatum { ..d, highestBid: Some( Bid {..b, value: 1000} ) }
      }
    }
  }
  run_test_make_bid(False, id, id, id, fixOutputAddressDatum(_, my_pub_key_hash, f), id, auction)
}

// highest bid is None
test test_correct_bid_output_datum_2() fail {
  let f = fn (d: LotDatum) -> LotDatum {
    LotDatum { ..d, highestBid: None }
  }
  run_test_make_bid(False, id, id, id, fixOutputAddressDatum(_, my_pub_key_hash, f), id, auction)
}

// highest bid is ok, but other field in the datum (minjBid) is not
test test_correct_bid_output_datum_3() fail {
  let f = fn (d: LotDatum) -> LotDatum {
    LotDatum { ..d, minBid: 101 }
  }
  run_test_make_bid(False, id, id, id, fixOutputAddressDatum(_, my_pub_key_hash, f), id, auction)
}

test test_check_transaction_output() {
  let auction1 = fn (
    _: LotDatum,
    _: AuctionRedeemer,
    ctx: ScriptContext,
  ) {
    expect [x, _, _] = ctx.transaction.outputs
    value.lovelace_of(x.value) == 1010 && value.quantity_of(x.value, some_policy_id, some_asset_name) == 1
  }
  run_test_make_bid(False, id, id, id, id, id, auction1)
}

fn fixOutputAddressValue(ol: List<OutputGen>, address: PubKeyHash, v: Value) -> List<OutputGen> {
  let fmap = fn (o: OutputGen) -> OutputGen {
    if o.address == address {
      OutputGen {..o, value: v }
    } else { o }
  }
  ol |> list.map(fmap)
}

// wrong lovelace value
test test_correct_bid_output_value_1() fail {
  run_test_make_bid(False, id, id, id, fixOutputAddressValue(_, my_pub_key_hash, mk_value_with_nft(1000)), id, auction)
}

// no nft
test test_correct_bid_output_value_2() fail {
  run_test_make_bid(False, id, id, id, fixOutputAddressValue(_, my_pub_key_hash, value.from_lovelace(1010)), id, auction)
}

// wrong nft
test test_correct_bid_output_value_3() fail {
  let mk_value_with_wrong_nft = fn (v: Int) {
    value.from_lovelace(v) |> value.add(some_policy_id, "wtf", 1)
  }
  run_test_make_bid(False, id, id, id, fixOutputAddressValue(_, my_pub_key_hash, mk_value_with_wrong_nft(1010)), id, auction)
}

// one more nft
test test_correct_bid_output_value_4() fail {
  let mk_value_with_2nft = fn (v: Int) {
    value.from_lovelace(v) |> value.add(some_policy_id, "wtf", 1)
                           |> value.add(some_policy_id, some_asset_name, 1)
  }
  run_test_make_bid(False, id, id, id, fixOutputAddressValue(_, my_pub_key_hash, mk_value_with_2nft(1010)), id, auction)
}

// incorrect refund value
test test_correct_bid_refund_1() fail {
  run_test_make_bid(False, id, id, id, fixOutputAddressValue(_, refund_pub_key_hash, value.from_lovelace(1001)), id, auction)
}

// no refund address
test test_correct_bid_refund_2() fail {
  let rm_refund_address = fn (ol: List<OutputGen>) -> List<OutputGen> {
    let o <- list.filter(ol, _)
    o.address != refund_pub_key_hash
  }
  run_test_make_bid(False, id, id, id, rm_refund_address, id, auction)
}

fn run_test_close(
  noBids: Bool,
  fixDatum: Alt<LotDatum>,
  fixRedeemer: Alt<AuctionRedeemer>,
  fixInputs: Alt<List<InputGen>>,
  fixOuputs: Alt<List<OutputGen>>,
  fixTransaction: Alt<Transaction>,
  auc: fn (LotDatum, AuctionRedeemer, ScriptContext) -> Bool,
) -> Bool {

  let d = LotDatum {
    seller:     seller_pub_key_hash,
    deadline:   10000,
    minBid:     100,
    policy_id:  some_policy_id,
    asset_name: some_asset_name,
    highestBid: if noBids { None } else { Some (Bid (refund_pub_key_hash, 1000)) },
  }

  let r = Close

  let (inputs, outputs) = if noBids {
    ([
      InputGen { tx: 0, address: my_pub_key_hash, value: mk_value_with_nft(1000), datum: Some(d) },
      InputGen { tx: 1, address: some_pub_key_hash, value: value.from_lovelace(100), datum: None },
    ], [
      OutputGen { address: some_pub_key_hash,   value: value.from_lovelace(100), datum: None },
      OutputGen { address: seller_pub_key_hash, value: value.from_asset(some_policy_id, some_asset_name, 1), datum: None },
    ])
  } else {
    ([
      InputGen { tx: 0, address: my_pub_key_hash, value: mk_value_with_nft(1000), datum: Some(d) },
      InputGen { tx: 1, address: some_pub_key_hash, value: value.from_lovelace(100), datum: None },
    ], [
      OutputGen { address: some_pub_key_hash,   value: value.from_lovelace(100), datum: None },
      OutputGen { address: refund_pub_key_hash, value: value.from_asset(some_policy_id, some_asset_name, 1), datum: None },
      OutputGen { address: seller_pub_key_hash, value: value.from_lovelace(1000), datum: None },
    ])
  }

  let t = Transaction { ..mk_transaction(fixInputs(inputs), fixOuputs(outputs)), validity_range: interval.entirely_after(11000) }

  auc(fixDatum(d), fixRedeemer(r), mk_context(fixTransaction(t)))
}

test test_run_close_no_bids() {
  run_test_close(True, id, id, id, id, id, auction)
}

test test_run_close() {
  run_test_close(False, id, id, id, id, id, auction)
}

fn fixOutputAddressRm(ol: List<OutputGen>, address: PubKeyHash) -> List<OutputGen> {
  let o <- list.filter(ol, _)
  o.address != address
}

// no output to seller
test test_seller_gets_token_1() fail {
  run_test_close(True, id, id, id, fixOutputAddressRm(_, seller_pub_key_hash), id, auction)
}

// wrong value sent to seller
test test_seller_gets_token_2() fail {
  run_test_close(True, id, id, id, fixOutputAddressValue(_, seller_pub_key_hash, value.from_lovelace(1001)), id, auction)
}

// no output to bidder
test test_bidder_gets_token_1() fail {
  run_test_close(False, id, id, id, fixOutputAddressRm(_, refund_pub_key_hash), id, auction)
}

// wrong value sent to bidder
test test_bidder_gets_token_2() fail {
  run_test_close(False, id, id, id, fixOutputAddressValue(_, refund_pub_key_hash, value.from_lovelace(1001)), id, auction)
}

// no output with ADA to seller
test test_seller_gets_highest_bid_1() fail {
  run_test_close(False, id, id, id, fixOutputAddressRm(_, seller_pub_key_hash), id, auction)
}

// wrong ADA value output to seller
test test_seller_gets_highest_bid_2() fail {
  run_test_close(False, id, id, id, fixOutputAddressValue(_, seller_pub_key_hash, value.from_lovelace(999)), id, auction)
}

fn fixTransactionValidityRange(t: Transaction, r: ValidityRange) -> Transaction {
  Transaction { ..t, validity_range: r }
}

test test_make_bid_validity_range_1() fail {
  run_test_make_bid(True, id, id, id, id, fixTransactionValidityRange(_, interval.everything()), auction)
}

test test_make_bid_validity_range_2() fail {
  run_test_make_bid(False, id, id, id, id, fixTransactionValidityRange(_, interval.everything()), auction)
}

test test_make_bid_validity_range_3() fail {
  run_test_make_bid(True, id, id, id, id, fixTransactionValidityRange(_, interval.between(9000, 11000)), auction)
}

test test_make_bid_validity_range_4() fail {
  run_test_make_bid(True, id, id, id, id, fixTransactionValidityRange(_, interval.before(11000)), auction)
}

test test_close_validity_range_1() fail {
  run_test_close(True, id, id, id, id, fixTransactionValidityRange(_, interval.everything()), auction)
}

test test_close_validity_range_2() fail {
  run_test_close(False, id, id, id, id, fixTransactionValidityRange(_, interval.everything()), auction)
}

test test_close_validity_range_3() fail {
  run_test_close(True, id, id, id, id, fixTransactionValidityRange(_, interval.between(9000, 11000)), auction)
}

test test_close_validity_range_4() fail {
  run_test_close(True, id, id, id, id, fixTransactionValidityRange(_, interval.before(11000)), auction)
}
