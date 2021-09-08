import { config } from "../config.ts";
import { Context } from "../context.ts";
import { Denops, op } from "../deps.ts";
import { test } from "../deps/denops_test.ts";
import { fromFileUrl } from "../deps/std/path.ts";
import { assertEquals } from "../deps/std/testing.ts";
import { main } from "../main.ts";
import { kakutei } from "./common.ts";
import { deleteChar, henkanPoint, katakana } from "./input.ts";
import { dispatch } from "./testutil.ts";

Deno.test({
  name: "kana input",
  async fn() {
    const context = new Context();
    for (const c of "nihongoutteiki") {
      await dispatch(context, c);
    }
    assertEquals(context.preEdit.output(""), "にほんごうっていき");
  },
});

Deno.test({
  name: "kana input with illegal key",
  async fn() {
    {
      const context = new Context();
      for (const c of "n n n n ") {
        await dispatch(context, c);
      }
      // the last space isn't decision yet.
      assertEquals(context.preEdit.output(""), "ん ん ん ん");
    }
    {
      const context = new Context();
      for (const c of "@a") {
        await dispatch(context, c);
      }
      assertEquals(context.preEdit.output(""), "@あ");
    }
  },
});

Deno.test({
  name: "henkan point",
  async fn() {
    const context = new Context();
    const tests = [
      [";", "▽"],
      [";", "▽"],
      ["y", "▽y"],
      ["a", "▽や"],
      [";", "▽や*"],
      [";", "▽や*"],
      ["t", "▽や*t"],
      ["t", "▽や*っt"],
      [";", "▽や*っt"],
    ];
    for (const test of tests) {
      await dispatch(context, test[0]);
      assertEquals(context.toString(), test[1]);
    }
  },
});

Deno.test({
  name: "upper case input",
  async fn() {
    {
      const context = new Context();
      for (const c of "HogeP") {
        await dispatch(context, c);
      }
      assertEquals(context.toString(), "▽ほげ*p");
    }
    {
      const context = new Context();
      for (const c of "sAsS") {
        await dispatch(context, c);
      }
      assertEquals(context.toString(), "▽さっ*s");
    }
  },
});

Deno.test({
  name: "delete char",
  async fn() {
    const context = new Context();
    for (const c of ";ya;tt") {
      await dispatch(context, c);
    }
    let result = context.toString();
    do {
      deleteChar(context);
      result = result.slice(0, -1);
      assertEquals(context.toString(), result);
    } while (result);
  },
});

Deno.test({
  name: "undo point",
  async fn() {
    {
      const context = new Context();
      context.vimMode = "i";
      await dispatch(context, "a");
      henkanPoint(context);
      assertEquals(context.preEdit.output(context.toString()), "あ\x07u▽");
    }
    // not emit at cmdline
    {
      const context = new Context();
      context.vimMode = "c";
      await dispatch(context, "a");
      henkanPoint(context);
      assertEquals(context.preEdit.output(context.toString()), "あ▽");
    }
  },
});

async function init(denops: Denops) {
  const p = fromFileUrl(new URL(import.meta.url));
  const autoload = p.slice(0, p.lastIndexOf("denops")) +
    "autoload/skkeleton.vim";
  await denops.cmd("source " + autoload);
  await main(denops);
}

config.globalJisyo = "";
config.userJisyo = "";

test({
  mode: "nvim",
  name: "new line",
  pluginName: "skkeleton",
  async fn(denops: Denops) {
    await init(denops);

    await op.autoindent.setLocal(denops, true)
    await denops.cmd("startinsert");
    await denops.cmd(
      "inoremap <expr> J denops#request('skkeleton', 'enable', [])",
    );
    await denops.call("feedkeys", "iJ\thoge\x0dhoge;hoge\x0d", "tx");
    assertEquals(await denops.call("getline", 1, "$"), ["\tほげ", "\tほげほげ", ""]);
  },
});

Deno.test({
  name: "katakana input",
  async fn() {
    const context = new Context();

    // change to katakana mode
    katakana(context);
    await dispatch(context, "a");
    assertEquals(context.preEdit.output(""), "ア");
    katakana(context);
    await dispatch(context, "a");
    assertEquals(context.preEdit.output(""), "あ");

    // henkan pre
    katakana(context);
    await dispatch(context, "N");
    assertEquals(context.toString(), "▽n");
    // and kakutei
    await kakutei(context);
    assertEquals(context.preEdit.output(""), "ン");

    katakana(context);
    // convert henkan pre
    await dispatch(context, "Hoge");
    katakana(context);
    assertEquals(context.preEdit.output(""), "ホゲ");
    // don't convert when converter enabled
    katakana(context);
    await dispatch(context, "Hoge");
    katakana(context);
    assertEquals(context.preEdit.output(""), "ほげ");
  },
});
