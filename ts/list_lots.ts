#!/usr/bin/env -S deno run --allow-env --allow-net

import { decode } from "https://deno.land/x/cbor@v1.5.9/index.js";

function ensureDefined<T>(value: T | undefined, error_message: string): T {
  if (value === undefined) {
    throw new Error(error_message);
  }
  return value;
}

function hexToUint8Array(hexString: string): Uint8Array {
  if (hexString.length % 2 !== 0) {
    throw new Error("Wrong hex string length");
  }
  const arrayBuffer = new Uint8Array(hexString.length / 2);
  for (let i = 0; i < hexString.length; i += 2) {
    const byteValue = parseInt(hexString.slice(i, i + 2), 16);
    arrayBuffer[i / 2] = byteValue;
  }
  return arrayBuffer;
}

const project_id = ensureDefined(
  Deno.env.get("BLOCKFROST_PROJECT_ID"),
  "BLOCKFROST_PROJECT_ID is not defined",
);

// const tx_hash = 'f32c9868bd2a4f79f141b8a4fe2a4254bcced0f6e7d4f5eb1e8553ed818559eb'
// const tx_id = 0

const api = "https://cardano-preview.blockfrost.io/api/v0";
const script_address =
  "addr_test1wqu0umjf6r3k6l9ae3h7k98zus2ra8tvg92pgam6j7mpxfgtwcqa9";

const resp = await fetch(api + "/addresses/" + script_address + "/utxos", {
  method: "GET",
  headers: {
    "Accept": "application/json",
    "project_id": project_id,
  },
});

// console.log(resp.status); // 200
// console.log(resp.headers.get("Content-Type")); // "text/html"

const data = JSON.parse(await resp.text());

if (!Array.isArray(data)) {
  throw new Error("Expected an array");
}

for (const elem of data) {
  console.log(elem.tx_hash, elem.output_index);
  const x = elem.inline_datum;
  if (x !== null) {
    const bytes = hexToUint8Array(x);
    const decoded = decode(bytes);
    console.log(decoded);

    console.log(decoded.tag);
  }
}

const json2 = JSON.stringify(data, null, 2);
console.log(json2);
