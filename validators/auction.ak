use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction.{
  Input, NoDatum, Output, OutputReference, ScriptContext, Spend, Transaction,
  TransactionId
}
use aiken/transaction/credential.{VerificationKey, from_script}
use aiken/transaction/value.{PolicyId, AssetName}
use aiken/time.{PosixTime}
use aiken/option

type PubKeyHash = Hash<Blake2b_224, VerificationKey>

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
    _ctx: ScriptContext,
  ) -> Bool {

    let sufficientBid = fn (bid: Bid) -> Bool {
      when data.highestBid is {
        None         -> data.minBid <= bid.value
        Some(oldBid) -> oldBid.value < bid.value
      }
    }

    let correctCloseSlotRange = True

    let correctBidOutputDatum = True

    let correctBidOutputValue = True

    let correctBidRefund = True

    let correctBidSlotRange = True

    when redeemer is {
      MakeBid ( bid ) -> sufficientBid(bid)
                      && correctBidOutputDatum
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

fn mk_output_reference() -> OutputReference {
  OutputReference { transaction_id: TransactionId(""), output_index: 0 }
}

fn mk_context(t: Transaction) -> ScriptContext {
  let purpose = Spend(mk_output_reference())
  ScriptContext { purpose, transaction: t }
}

fn mk_transaction(fee: Int) -> Transaction {
  transaction.placeholder()
    |> fn(t) { Transaction { ..t, fee: value.from_lovelace(fee) } }
}

fn mk_input(value: Int) -> Input {
  let output =
    Output {
      address: from_script(""),
      value: value.from_lovelace(value),
      datum: NoDatum,
      reference_script: None,
    }
  Input { output_reference: mk_output_reference(), output }
}

fn add_value(p: Transaction, value: Int) -> Transaction {
  let i = mk_input(value)
  Transaction { ..p, inputs: [i, ..p.inputs] }
}

fn arbitrary_pub_key_hash() -> PubKeyHash { #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50" }

fn mk_insufficient_bid_test(bid: Int, minBid: Int, highestBid: Option<Int>) -> Bool {
  let f = fn (v: Int) -> Bid {
    Bid(arbitrary_pub_key_hash(), v)
  }
  auction(
    LotDatum {
      seller:     arbitrary_pub_key_hash(),
      deadline:   10,
      minBid:     minBid,
      currency:   arbitrary_pub_key_hash(),
      token:      "asdf",
      highestBid: highestBid |> option.map(f),
    },
    MakeBid (
      Bid {
        bidOwner: arbitrary_pub_key_hash(),
        value: bid,
      }
    ),
    mk_context(mk_transaction(5) |> add_value(2) |> add_value(3)),
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

// fn should_provide_value(_transaction: Transaction, _value: Int) -> Bool {
//   True
// }
//
// fn bid_parameters_are_ok(lotData: LotData) -> Bool {
//   lotData.startingBid > 0 && lotData.bidIncrement > 0
// }
//
// type LotValue {
//   policyId: PolicyId,
//   asserName: AssetName,
//   value: Int,
// }
//
// fn value_has_unique_nonada_value(_v: Value) -> Option<LotValue> {
//   None
// }
//
// //
// fn other_inputs_dont_have_nonada_values(_inputs: List<Input>, _output_reference: OutputReference) -> Bool {
//   True
// }
//
// fn find_unique_nonada_output() -> Option<LotValue> {
//   None
// }
//
// fn lot_passed_from_input_to_output(_data: LotData, _bit: Bid, ctx: ScriptContext) -> Bool {
//
//   // find input where the lot and the locked bids locked
//   expect Spend(lot_output_reference) = ctx.purpose
//   expect Some(input) = find_input(ctx.transaction.inputs, lot_output_reference)
//   expect True = other_inputs_dont_have_nonada_values(ctx.transaction.inputs, lot_output_reference)
//
//   expect Some(lot_input) = value_has_unique_nonada_value(input.output.value)
//   expect Some(lot_output) = find_unique_nonada_output()
//
//   lot_input == lot_output
// }
//
// fn must_be_signed_by(transaction: Transaction, vk: PubKeyHash) -> Bool {
//   list.has(transaction.extra_signatories, vk)
// }

// fn must_happen_before(range: ValidityRange, lock_expiration_time: PosixTime) {
//   when range.upper_bound.bound_type is {
//     Finite(tx_latest_time) -> lock_expiration_time <= tx_latest_time
//     _ -> False
//   }
// }
//
// fn must_match_price(inputs: List<Input>, fee_value: Value, price: Int) {
//   let f =
//     fn(i: Input, v: Int) -> Int { value.lovelace_of(i.output.value) + v }
//
//   let sum_of_inputs = list.foldl(inputs, 0, f)
//
//   let fee = value.lovelace_of(fee_value)
//
//   sum_of_inputs - fee >= price
// }
