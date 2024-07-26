#!/usr/bin/env -S deno run --allow-env --allow-net

function ensureDefined<T>(value: T | undefined, error_message: string): T {
    if (value === undefined) {
      throw new Error(error_message);
    }
    return value;
}

const project_id = ensureDefined(Deno.env.get("BLOCKFROST_PROJECT_ID"), "BLOCKFROST_PROJECT_ID is not defined")
console.log(project_id);

// const tx_hash = 'f32c9868bd2a4f79f141b8a4fe2a4254bcced0f6e7d4f5eb1e8553ed818559eb'
// const tx_id = 0

const api = 'https://cardano-preview.blockfrost.io/api/v0'
const script_address = 'addr_test1wqu0umjf6r3k6l9ae3h7k98zus2ra8tvg92pgam6j7mpxfgtwcqa9'

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

// console.log(await resp.text()); // "Hello, World!"

const json2 = JSON.stringify(data, null, 2);
console.log(json2);

