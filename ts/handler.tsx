/** @jsx h */

import { h, jsx } from "https://deno.land/x/sift@0.6.0/mod.ts";

function ensureDefined<T>(value: T | undefined, error_message: string): T {
    if (value === undefined) {
      throw new Error(error_message);
    }
    return value;
  }

const project_id = ensureDefined(
    Deno.env.get("BLOCKFROST_PROJECT_ID"),
    "BLOCKFROST_PROJECT_ID is not defined",
  );

const api = "https://cardano-preview.blockfrost.io/api/v0";
const script_address = Deno.readTextFileSync("cli/contract_address.txt");

export async function handler(_req: Request, _info: Deno.ServeHandlerInfo) : Promise<Response> {

    const resp = await fetch(api + "/addresses/" + script_address + "/utxos", {
      method: "GET",
      headers: {
        "Accept": "application/json",
        "project_id": project_id,
      },
    });

    const data = await resp.json();

    if (!Array.isArray(data)) {
      throw new Error("Expected an array");
    }

    const html = (
      <div>
        <h1>Aiken auction</h1>
        {data.length > 0 ? "UTXOs:" : "No UTXOs"}
        {data.map((e, i) => (
          <span>
            <a href={`https://preview.beta.explorer.cardano.org/en/transaction/${e.tx_hash}#${e.output_index}`}>
              {i + 1}
            </a>
            {i < data.length - 1 && ","}
          </span>
        ))}
      </div>
    );

    return jsx(html);
}