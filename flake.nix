{
  description = "SKK implements for Vim/Neovim with denops.vim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # TODO: remove git revision when upstream's treesitter issue is fixed and we can build it on HEAD
    neovim-flake.url = "github:neovim/neovim/4e59422e1d4950a3042bad41a7b81c8db4f8b648?dir=contrib";
    ddc-vim = {
      url = "github:Shougo/ddc.vim";
      flake = false;
    };
    cmp-skkeleton = {
      url = "github:uga-rosa/cmp-skkeleton";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      neovim-flake,
      ...
    }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (pkgs) lib;

          neovim-head = pkgs.wrapNeovim neovim-flake.packages.${system}.default { };

          skkeleton = pkgs.vimUtils.buildVimPlugin {
            pname = "skkeleton";
            version = self.shortRev or "dirty";

            src = ./.;

            dependencies = with pkgs.vimPlugins; [ denops-vim ];

            dontBuild = true;
          };

          ddc-vim = pkgs.vimUtils.buildVimPlugin {
            pname = "ddc.vim";
            version = inputs.ddc-vim.shortRev or "dirty";

            src = inputs.ddc-vim;

            dependencies = with pkgs.vimPlugins; [ denops-vim ];

            dontBuild = true;
          };

          cmp-skkeleton = pkgs.vimUtils.buildVimPlugin {
            pname = "cmp-skkeleton";
            version = inputs.cmp-skkeleton.shortRev or "dirty";

            src = inputs.cmp-skkeleton;

            dependencies = [
              self.outputs.packages.${system}.skkeleton
              pkgs.vimPlugins.nvim-cmp
            ];

            dontBuild = true;
          };

          skkeleton-config = ''
            call skkeleton#config({ 'globalDictionaries': ["${pkgs.skk-dicts}/share/SKK-JISYO.L"] })

            imap <C-j> <Plug>(skkeleton-toggle)
            cmap <C-j> <Plug>(skkeleton-toggle)
          '';

          nvim-cmp-config = ''
            lua << EOF
            local cmp = require('cmp')

            cmp.setup({
              mapping = cmp.mapping.preset.insert({
                ['<C-b>'] = cmp.mapping.scroll_docs(-4),
                ['<C-f>'] = cmp.mapping.scroll_docs(4),
                ['<C-Space>'] = cmp.mapping.complete(),
                ['<C-e>'] = cmp.mapping.abort(),
                ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
              }),
              sources = cmp.config.sources({
                { name = "skkeleton" },
              })
            })
            EOF
          '';

          ddc-config = ''
            call ddc#custom#patch_global('sources', ['skkeleton'])
            call ddc#custom#patch_global('sourceOptions', {
                \   'skkeleton': {
                \     'mark': 'skkeleton',
                \     'matchers': [],
                \     'sorters': [],
                \     'converters': [],
                \     'isVolatile': v:true,
                \     'minAutoCompleteLength': 1,
                \   },
                \ })
            call ddc#enable()
          '';

          vim-with-config =
            {
              withDdc ? false,
            }:
            pkgs.vim-full.customize {
              vimrcConfig = {
                customRC = skkeleton-config + lib.optionalString withDdc ddc-config;
                packages.example.start = [ skkeleton ] ++ lib.optionals withDdc [ ddc-vim ];
              };
            };

          neovim-with-config =
            {
              neovim ? pkgs.neovim,
              withNvimCmp ? false,
              withDdc ? false,
            }:
            neovim.override {
              configure = {
                customRC =
                  skkeleton-config
                  + lib.optionalString withDdc ddc-config
                  + lib.optionalString withNvimCmp nvim-cmp-config;

                packages.example.start = [
                  skkeleton
                ] ++ lib.optionals withNvimCmp [ cmp-skkeleton ] ++ lib.optionals withDdc [ ddc-vim ];
              };
            };
        in
        {
          inherit skkeleton;
          default = skkeleton;

          vim-skkeleton = vim-with-config { };
          vim-skkeleton-with-ddc = vim-with-config { withDdc = true; };

          neovim-skkeleton = neovim-with-config { };
          neovim-skkeleton-with-nvim-cmp = neovim-with-config { withNvimCmp = true; };
          neovim-skkeleton-with-ddc = neovim-with-config { withDdc = true; };

          neovim-head-skkeleton = neovim-with-config { neovim = neovim-head; };
          neovim-head-skkeleton-with-nvim-cmp = neovim-with-config {
            neovim = neovim-head;
            withNvimCmp = true;
          };
          neovim-head-skkeleton-with-ddc = neovim-with-config {
            neovim = neovim-head;
            withDdc = true;
          };
        }
      );
    };
}
