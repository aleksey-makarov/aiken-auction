use aiken/transaction.{
  Mint, OutputReference, ScriptContext, Transaction
}
use aiken/transaction/value
use aiken/dict
use aiken/list

validator(token_name: ByteArray, utxo_ref: OutputReference) {
  fn nft(
    _: Data,
    ctx: ScriptContext,
  ) -> Bool {

    let ScriptContext { transaction, purpose } = ctx
    let Transaction { inputs, mint, .. } = transaction

    expect Mint(policy_id) = purpose

    expect [(asset_name, amount)] =
      mint
        |> value.from_minted_value
        |> value.tokens(policy_id)
        |> dict.to_list()

    expect Some(_) = list.find(inputs, fn(input) { input.output_reference == utxo_ref }) 
    amount == 1 && asset_name == token_name

  }
}