#!/usr/bin/env -S deno run --allow-env --allow-net

import {
  applyDoubleCborEncoding,
  applyParamsToScript,
  Constr,
  Data,
  fromText,
  Lucid,
  MintingPolicy,
  OutRef,
  SpendingValidator,
} from "https://deno.land/x/lucid@0.10.7/mod.ts";

import blueprint from "../plutus.json" with { type: "json" };

export type Preamble = {
  title: string;
  description?: string;
  version: string;
  plutusVersion: string;
  license?: string;
};

export type Argument = {
  title?: string;
  description?: string;
  // schema: Record<string, unknown>;
};

export type Validator = {
  title: string;
  description?: string;
  datum?: Argument;
  redeemer: Argument;
  parameters?: Argument[];
  compiledCode: string;
  hash: string;
};

export type Blueprint = {
  preamble: Preamble;
  validators: Validator[];
};

export type Validators = {
  redeem: SpendingValidator;
  giftCard: MintingPolicy;
};

export type LocalCache = {
  tokenName: string;
  giftADA: string;
  lockTxHash: string;
  parameterizedValidators: AppliedValidators;
};

export type AppliedValidators = {
  redeem: SpendingValidator;
  giftCard: MintingPolicy;
  policyId: string;
  lockAddress: string;
};

export function applyParams(
  tokenName: string,
  outputReference: OutRef,
  validators: Validators,
  lucid: Lucid,
): AppliedValidators {
  const outRef = new Constr(0, [
    new Constr(0, [outputReference.txHash]),
    BigInt(outputReference.outputIndex),
  ]);

  const giftCard = applyParamsToScript(validators.giftCard.script, [
    fromText(tokenName),
    outRef,
  ]);

  const policyId = lucid.utils.validatorToScriptHash({
    type: "PlutusV2",
    script: giftCard,
  });

  const redeem = applyParamsToScript(validators.redeem.script, [
    fromText(tokenName),
    policyId,
  ]);

  const lockAddress = lucid.utils.validatorToAddress({
    type: "PlutusV2",
    script: redeem,
  });

  return {
    redeem: { type: "PlutusV2", script: applyDoubleCborEncoding(redeem) },
    giftCard: { type: "PlutusV2", script: applyDoubleCborEncoding(giftCard) },
    policyId,
    lockAddress,
  };
}

console.log("start")

const nft_script = (blueprint as Blueprint).validators.find((v) => v.title === "nft.nft");
if (!nft_script) {
  throw new Error("Nft validator script not found");
}

const nft_validator : MintingPolicy = {
  type: "PlutusV2",
  script: nft_script.compiledCode,
}

const tokenName : string  = "some_token"
const outRef : OutRef = {
  outputIndex: 0,
  txHash: ""
}

const a : Data = ""

const nft_script_parametrized = applyParamsToScript(nft_validator.script, [
  fromText(tokenName)
  // outRef
]);


// readValidators()
console.log("done")
