# aiken-auction

> A naïve implementation of simple
> [forward](https://en.wikipedia.org/wiki/Forward_auction)
> auction for
> [Cardano](https://cardano.org/)
> blockchain in
> [Aiken](https://aiken-lang.org/)
> programming language.
> This is an education project for
> [Eurgo Academy](https://education.emurgo.io/)
> "Cardano Developer Professional" programm.

## Protocol

Clients to this service want to sell their NFTs (*sellers*).
They deposit their tokens to the script address.
Other clients that are interested in that NFT (*bidders*) make bids.
When *seller* decides to sell his lot to the best bidder,
he can withdraw the (t)Ada.
After that the *bidder* can withdraw the NFT.

Let's call any eUTxO on the address of the smart contract *lot*.

### Listing

To participate in the auction, *seller* issues a transaction with uTXO to the contract address.
This uTXO should have exactly one token as its value and data of type `LotData`.

```Rust
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
```

The `lotOwner` should be the seller's public key hash.
`startingBid` and `bidIncrement` should be the starting bid and bid increment,
`bids` list should be empty, `taken` should be false.

### Bidding

When *Bidder* wants to make a bid, it issues a transaction
that has the *lot* as an input, to the auction script address as an output.
`MkBid` constructor of type `AuctionRedeemer` should be specified as a redeemer.

```Rust
type AuctionRedeemer {
  MkBid { bidOwner: VerificationKeyHash, value: Int, }
  TakeBid
  ReturnBid
  ReceiveLot
}
```

`bidOwner` should be the bidder's public key hash,
`bidValue` should be the value of the bid.
In a separate input *bidder* should provide the bid whose value should not be less than
`bidValue` in lovelace.

### Taking a bid

When *seller* decides to take a bid, he creates a transaction with the `TakeBid` constructor.
One of its output should be to the script's address, another one -- to the *seller*'s address,
withdrawing the value of the biggest bid.

### Returning a bid

Similarly *Bidders* whose bid did not paid off can return the blocked value providing
`ReturnBid` as a redeemer.

### Receiving the lot

Similarly *Bidders* whose bid paid off can receive the lot providing `ReturnBid` as a redeemer.
