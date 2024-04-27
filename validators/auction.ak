use aiken/hash.{Blake2b_224, Hash}
use aiken/interval.{Finite}
use aiken/list
use aiken/time.{PosixTime}
use aiken/transaction.{
  Input, NoDatum, Output, OutputReference, ScriptContext, Spend, Transaction,
  TransactionId, ValidityRange,
}
use aiken/transaction/credential.{VerificationKey, from_script}
use aiken/transaction/value.{Value}

type VerificationKeyHash =
  Hash<Blake2b_224, VerificationKey>

// type AuctionParameters {
// 	ownerKey: VerificationKeyHash,
// }

type ConditionsRedeemer {
  action: Action,
  deadline: PosixTime,
  owner: VerificationKeyHash,
  price: Int,
}

type Action {
  Owner
  Time
  Price
}


validator {
  fn eaCoins(redeemer: ConditionsRedeemer, ctx: ScriptContext) -> Bool {
    when redeemer.action is {
      Owner -> must_be_signed_by(ctx.transaction, redeemer.owner)
      Time ->
        must_happen_before(ctx.transaction.validity_range, redeemer.deadline)
      Price ->
        must_match_price(
          ctx.transaction.inputs,
          ctx.transaction.fee,
          redeemer.price,
        )
    }
  }
}

fn must_be_signed_by(transaction: Transaction, vk: VerificationKeyHash) {
  list.has(transaction.extra_signatories, vk)
}

fn must_happen_before(range: ValidityRange, lock_expiration_time: PosixTime) {
  when range.upper_bound.bound_type is {
    Finite(tx_latest_time) -> lock_expiration_time <= tx_latest_time
    _ -> False
  }
}

fn must_match_price(inputs: List<Input>, fee_value: Value, price: Int) {
  let f =
    fn(i: Input, v: Int) -> Int { value.lovelace_of(i.output.value) + v }

  let sum_of_inputs = list.foldl(inputs, 0, f)

  let fee = value.lovelace_of(fee_value)

  sum_of_inputs - fee >= price
}

// tests -----------------------------------------------------

fn mk_output_reference() -> OutputReference {
  OutputReference { transaction_id: TransactionId(""), output_index: 0 }
}

fn mk_price_redeemer(v: Int) -> ConditionsRedeemer {
  ConditionsRedeemer { action: Price, deadline: 0, owner: "", price: v }
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
  eaCoins(
    mk_price_redeemer(10),
    mk_context(mk_transaction(5) |> add_value(2) |> add_value(3)),
  )
}

test test2() fail {
  eaCoins(
    mk_price_redeemer(10),
    mk_context(mk_transaction(5) |> add_value(6) |> add_value(7)),
  )
}

test test3() {
  eaCoins(
    mk_price_redeemer(10),
    mk_context(mk_transaction(5) |> add_value(8) |> add_value(9)),
  )
}

test test4() {
  eaCoins(
    mk_price_redeemer(10),
    mk_context(mk_transaction(10) |> add_value(12) |> add_value(13)),
  )
}
