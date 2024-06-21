# aiken-auction

> A naïve implementation of simple
> [forward](https://en.wikipedia.org/wiki/Forward_auction)
> auction for
> [Cardano](https://cardano.org/)
> blockchain in
> [Aiken](https://aiken-lang.org/)
> programming language.
> This is an education project for
> [Emurgo Academy](https://education.emurgo.io/)
> "Cardano Developer Professional" program.

This is a rewrite in Aiken of an educational project by
[Plutus Pioneer Program](https://plutus-pioneer-program.readthedocs.io/en/latest/pioneer/week1.html).

The original code is here:
[EnglishAuction.hs](https://github.com/input-output-hk/plutus-pioneer-program/blob/second-iteration/code/week01/src/Week01/EnglishAuction.hs).

## Protocol

Clients to this service want to sell their NFTs (*sellers*).
They deposit their tokens to the script address, specifying time in the future when the auction
should be closed.
Other clients that are interested in that NFT (*bidders*) make bids by locking ADA values in the contract address.
When the time period specified by *seller* is over, he can close the auction.
When the *seller* closes auction, if there were bids then it receives the locked ADA and sends the lot to the last bidder,
if not, he receives the lot back.

Let's call any eUTxO on the address of the smart contract *lot*.

### Listing

To participate in the auction, *seller* issues a transaction with eUTxO to the contract address.
This eUTxO should have exactly one token as its value and data of type `LotDatum`.

```Rust
type Bid {
  bidOwner: VerificationKeyHash,
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
```

The `seller` fileld should be the seller's public key hash.
`deadline` is the time after which the auction should be losed
`minBid` is minimal bid,
`currency` and `token` specify the NFT locked by seller,
`highestBid` is the last bid.

### Bidding

When *Bidder* wants to make a bid, it issues a transaction
that has the *lot* as an input, to the auction script address as an output.
`MakeBid` constructor of type `AuctionRedeemer` should be specified as a redeemer.
If is is not the first bid, the transaction should also return the locked value to
the previous *bidder*.

```Rust
type AuctionRedeemer {
  MakeBid(Bid)
  Close
}
```

### Closing the auction

When the aution timeframe is over and no bids were made, *seller* should get its NFT back.
If there were bids, he should send the locked NFT to the last *bidder* and receive
the ADA locked by the last *bidder*.

## Status

**21 June 2024**:
Everything is implemented and tested with 38 test cases.
Tested on `preview` network, see `cli/auction_*.sh`
