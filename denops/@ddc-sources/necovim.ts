import {
  BaseSource,
  Context,
  Item,
} from "https://deno.land/x/ddc_vim@v3.1.0/types.ts";
import { Denops } from "https://deno.land/x/ddc_vim@v3.1.0/deps.ts";

type Params = Record<never, never>;

export class Source extends BaseSource<Params> {
  isBytePos = true;

  async getCompletePosition(args: {
    denops: Denops,
    context: Context,
  }): Promise<number> {
    return await args.denops.call(
      'necovim#get_complete_position', args.context.input) as number;
  }

  async gather(args: {
    denops: Denops,
    context: Context,
    completeStr: string,
  }): Promise<Item[]> {
    return await args.denops.call(
        'necovim#gather_candidates',
        args.context.input, args.completeStr) as Item[];
  }

  params(): Params { return {}; }
}
