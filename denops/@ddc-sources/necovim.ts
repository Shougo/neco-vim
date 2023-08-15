import {
  BaseSource,
  Context,
  Item,
  Previewer,
} from "https://deno.land/x/ddc_vim@v4.0.4/types.ts";
import { Denops, fn } from "https://deno.land/x/ddc_vim@v4.0.4/deps.ts";

type Params = Record<string, never>;

export class Source extends BaseSource<Params> {
  isBytePos = true;

  override async getCompletePosition(args: {
    denops: Denops,
    context: Context,
  }): Promise<number> {
    return await args.denops.call(
      'necovim#get_complete_position', args.context.input) as number;
  }

  override async gather(args: {
    denops: Denops,
    context: Context,
    completeStr: string,
  }): Promise<Item[]> {
    return await args.denops.call(
        'necovim#gather_candidates',
        args.context.input, args.completeStr) as Item[];
  }

  override async getPreviewer(args: {
    denops: Denops,
    item: Item;
  }): Promise<Previewer> {
    const help = await fn.getcompletion(args.denops, args.item.word, "help");
    if (help.length === 0) {
      return {
        kind: "empty",
      };
    } else {
      return {
        kind: "help",
        tag: args.item.word,
      };
    }
  }

  override params(): Params { return {}; }
}
