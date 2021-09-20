import {
  BaseSource,
  Candidate,
  Context,
} from "https://deno.land/x/ddc_vim@v0.13.0/types.ts";
import { Denops } from "https://deno.land/x/ddc_vim@v0.13.0/deps.ts";

export class Source extends BaseSource<{}> {
  isBytePos = true;

  async getCompletePosition(args: {
    denops: Denops,
    context: Context,
  }): Promise<number> {
    return await args.denops.call(
      'necovim#get_complete_position', args.context.input) as number;
  }

  async gatherCandidates(args: {
    denops: Denops,
    context: Context,
    completeStr: string,
  }): Promise<Candidate[]> {
    return await args.denops.call(
        'necovim#gather_candidates',
        args.context.input, args.completeStr) as Candidate[];
  }

  params(): {} { return {}; }
}
