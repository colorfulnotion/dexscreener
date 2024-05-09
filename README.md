# Dexscreener Integration 

|                 |                                                                                                    |
| --------------- | -------------------------------------------------------------------------------------------------- |
| **Drafted Date**  | May 9 2024 |
| **Implementation**  | May 13 2024 - July 12 2024 |
| **Description** | Develop open source DEXScreener integration   |
| **Authors**     | Sourabh Niyogi and Matthias Funke  |

## Summary

[Dexscreener](https://dexscreener.com/) is a leading user interface for active traders, summarizing recent DEX activity.  Currently DEXScreener represents Stellaswap (on Moonbeam) but otherwise has poor coverage of the Polkadot ecosystem.  This proposal concerns developing Dexscreener in the next 60 days for:
* HydraDX, a leading Substrate chain with full suite of DEX/Defi functionality
* AssetHub, a system chain with lightweight functionality 

It is expected that other defi Polkadot parachains can use the endpoint of this to implement similar DEX indexing for their chain.  

## Implementation

The implementation will be done with a completely self-contained Docker container, with a Node.js  based indexer using a MySQL backend, following the [Dexscreener specification](https://dexscreener.notion.site/DEX-Screener-Adapter-Specs-cc1223cdf6e74a7799599106b65dcd0e).  A small number of tables `block`, `asset`, `pair`,  `event` will be used for indexing and support the following 4 endpoints

####  Block:  `GET /latest-block`
 Returns the latest block where data from `/events` will be available

```
{
  "block": {
    "blockNumber": 12341234,
    "blockTimestamp": 1698126147
  }
}
```

* `blockTimestamp` is from `set.timestamp`
* only finalized blocks will be indexed


#### Asset  `GET /asset?id=:string`

Returns information about an asset on the specific parachain.  We use the `id` from the `assets` pallet in AssetHub (e.g. 1984 for USDT) or `assetRegistry` pallet in HydraDX (e.g. 26 for NODL)

How do we tell dexscreener which assets we have? Is that a separate endpoint?


```
{
  "asset": {
    "id": "1000019",
    "name": "DED",
    "symbol": "DED",
    "totalSupply": 10000000,
    "circulatingSupply": 900000,
    "coinGeckoId": "moonbeam"
  }
}
```

* Hydradx: `assetRegistry.assets` and `xyk.poolAssets`  (we need to join some off-chain metadata, e.g. symbol and coinGeckoId)

Which fields are optional? There may not be a coinGeckoId for all assets, or the circulating supply may not be known.

* AssetHub: `assets.asset` and `poolassets.asset`
 
#### Pair - `GET /pair?id=:string`

We agree that the IDs will always be sorted in ascending order (using numbers, not strings), so we can use a string like `5-100019` for the pair of assets with IDs 5 and 100019.  
The other pair does not exist.

```
{
  "pair": {
    "id": "5-100019",
	"dexKey": "hydradx",
    "asset0Id": "5",
    "asset1Id": "100019",
    "feeBps": 30
  }
}
```

* `id` will be from `xyk.poolAssets` or `poolassets.asset`, with `asset0Id` and `asset1ID` resolvable 
* **Question**: how do we treat `feeBps` for Hydradx

#### Events - `GET /events?fromBlock=:number&toBlock=:number`

Returns Swap events (eventType = swap) and Pool add/remove liquidity events
```
{
  "events": [
    {
      "block": {
        "blockNumber": 12344321,
        "blockTimestamp": 1673319600
      },
      "eventType": "swap",
	  "txnId": "0x1118d6bde171a4df1238f5eb69c4b9fff4d4e0169c91268dfa3661d6571faea9",
	  "txnIndex": 3,
	   "eventIndex": "12344321-5",
	   "maker": "7KjNuVyjY5Jv3znWGXSBBHt7Ls6Uwm1LmhswrGGDSYNUAwKW",
       "pairId": "5-100019",
       "asset0In": 10000,
       "asset1Out": 20000,
       "priceNative": 2,
       "reserves": { "asset0": 100, "asset1": 50 }
    },
    ...
  ]
}
```

* `txnID` is the ExtrinsicHash 
* `txnIndex` is the ExtrinsicID 
* `maker` is the ss58 address of the signer of the extrinsic (DISCUSS: technically the signer is the taker)
* `pairId` matches the `pair` 
* `asset0In` and `asset1Out` are taken directly from the event. (NO: we need to map the routed swap to the pair)
*  **Question**: What is the strategy for `reserves` and pool add/remove events in Hydradx omnipool?


## General Behavior / Implementation Notes

* Upon indexer start, the blocks will starting indexing from N blocks from the present, like N=1000, and will proceed _sequentially_.  The asset registry will be polled if empty.
* An array of RPC endpoints will be specified in the config.  A random one will be chosen from the array and upon any failure a round-robin approach will be used.
* Upon encountering an unknown assetid, the asset registry will be polled
* The MySQL database will be be filled with asset, events, blocks, etc. and storing them in a way that makes it trivial to query.  Each call by dexscreener to one of the endpoints results in a query to this MySQL database.  

Our expectation is that the Dexscreener will link users directly to a swap interface:
* dexKey=hydradx [https://app.hydradx.io/trade/swap?assetIn=5&assetOut=1000019]
* dexKey=assethub [https://dotswap.org/swap?from=DOT&to=PINK](https://dotswap.org/swap?from=DOT&to=PINK)

and for pools:
* dexKey=hydradx TBD
* dexKey=assethub https://assethub-polkadot.subscan.io/account/16XE9vmK76dkULyjxbHZzYxaG1rXQzo1fr6wsA3DogNkgKmn

**Question**: Is this touch point correct?  We believe this has implications on what the assetid and pairid should be, and directly constrains the following question.


### Key Events for HydraDX

#### Omnipool vs Isolated Pools

* SwapEvents and Pairs: Treatment for LRNA to be discussed
* Join/Exit events: to be discussed
* Isolated To be discussed

Assumption is that most people using dexScreener are degens or arbitrageurs. They cannot buy LRNA, therefore we can pretend LRNA does not exist?  The only issue is that some transactions will be censored, but there are situations where LPs are paid in LRNA, and the LRNA is then swapped for something else.


**Question: How should complex trades be mapped to events?**

We need to calculate the mapping from a routed swap to one or more pairs, implemented in the dexscreener indexer.  Matthias recommends we create the pairs dynamically based on some threshold of volume, in which case its a question of which pairs to "virtually" create.

iBTC to USDT might go like this:
* iBTC -- 2pool --> 4pool -> USDT. Coded as iBTC->USDT
* iBTC to WBTC is a stable swap. Coded as iBTC->WBTC
* DOT to GLMR coded as DOT->GLMR
* DOT to USDT goes via 2-pool-USD but coded as DOT->USDT
* LRNA to USDT : censored.

...
If someone actually has 2-pool or 4-pool tokens we map them as follows:
* 2-pool-USD to USDT
* 4-pool-USD to USDC
* 2-pool-BTC to WBTC

HydraDX Examples:
* _Matthias to provide HydraDX extrinsicIDs for us to map into JSON "events" of all swap cases as well as liquidity cases_


### Key Events for AssetHub

* `assetConversion.SwapExecuted' https://assethub-polkadot.subscan.io/extrinsic/6160981-2
* `assetConversion.LiquidityAdded' https://assethub-polkadot.subscan.io/extrinsic/6144216-2
* `assetConversion.LiquidityRemoved'

