
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

    const txt_array: string[] = [];

    for (const elem of data) {
        txt_array.push(elem.tx_hash + " " + elem.output_index);
    }

    return new Response(txt_array.join("\n"));
}