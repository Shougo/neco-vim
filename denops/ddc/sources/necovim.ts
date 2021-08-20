import {
  BaseSource,
  Candidate,
  Context,
  DdcOptions,
  SourceOptions,
} from "https://deno.land/x/ddc_vim@v0.0.15/types.ts";
import { Denops } from "https://deno.land/x/ddc_vim@v0.0.15/deps.ts";

export class Source extends BaseSource {
  isBytePos = true;

  async getCompletePosition(
    denops: Denops,
    context: Context,
    _options: DdcOptions,
    _sourceOptions: SourceOptions,
    _sourceParams: Record<string, unknown>,
  ): Promise<number> {
    return denops.call('necovim#get_complete_position', context.input);
  }

  async gatherCandidates(
    denops: Denops,
    context: Context,
    _ddcOptions: DdcOptions,
    _sourceOptions: SourceOptions,
    _sourceParams: Record<string, unknown>,
    completeStr: string,
  ): Promise<Candidate[]> {
    return denops.call(
        'necovim#gather_candidates', context.input, completeStr);
  }
}
