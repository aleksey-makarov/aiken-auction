use aiken/hash.{Blake2b_224, Hash}
use aiken/list
use aiken/transaction.{
  Input, NoDatum, Output, OutputReference, ScriptContext, Spend, Transaction,
  TransactionId,
}
use aiken/transaction/credential.{VerificationKey, from_script}
use aiken/transaction/value

type VerificationKeyHash =
  Hash<Blake2b_224, VerificationKey>

// ---------------------------------------------------------------------

type Bid {
  bidOwner: VerificationKeyHash,
  value: Int,
}

type LotData {
  lotOwner: VerificationKeyHash,
  startingBid: Int,
  bidIncrement: Int,
  bids: List<Bid>,
  taken: Bool,
}

type AuctionRedeemer {
  MkBid { bidOwner: VerificationKeyHash, value: Int }
  TakeBid
  ReturnBid
  ReceiveLot
}

validator {
  fn auction(
    _data: LotData,
    redeemer: AuctionRedeemer,
    ctx: ScriptContext,
  ) -> Bool {
    when redeemer is {
      MkBid { bidOwner, value } ->
        must_be_signed_by(ctx.transaction, bidOwner) && should_provide_value(
          ctx.transaction,
          value,
        ) && something_else(ctx.transaction)
      TakeBid -> False
      ReturnBid -> False
      ReceiveLot -> False
    }
  }
}

// ---------------------------------------------------------------------

fn must_be_signed_by(transaction: Transaction, vk: VerificationKeyHash) -> Bool {
  list.has(transaction.extra_signatories, vk)
}

fn should_provide_value(_transaction: Transaction, _value: Int) -> Bool {
  False
}

fn something_else(_transaction: Transaction) -> Bool {
  False
}

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

// tests -----------------------------------------------------

fn mk_output_reference() -> OutputReference {
  OutputReference { transaction_id: TransactionId(""), output_index: 0 }
}

fn mk_mk_bid_redeemer() -> AuctionRedeemer {
  MkBid { bidOwner: "", value: 42 }
}

fn mk_lot_data() -> LotData {
  LotData {
    lotOwner: "",
    startingBid: 42,
    bidIncrement: 10,
    bids: [],
    taken: False,
  }
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

fn mk_context(t: Transaction) -> ScriptContext {
  let purpose = Spend(mk_output_reference())
  ScriptContext { purpose, transaction: t }
}

test test1() fail {
  auction(
    mk_lot_data(),
    mk_mk_bid_redeemer(),
    mk_context(mk_transaction(5) |> add_value(2) |> add_value(3)),
  )
}
