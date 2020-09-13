#=============================================================================
# FILE: vim.py
# AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
# License: MIT license
#=============================================================================

from deoplete.base.source import Base

import deoplete.util

class Source(Base):
    def __init__(self, vim):
        Base.__init__(self, vim)

        self.name = 'vim'
        self.mark = '[vim]'
        self.filetypes = ['vim']
        self.is_bytepos = True
        self.rank = 500
        self.input_pattern = r'\.\w*'

    def get_complete_position(self, context):
        return self.vim.call('necovim#get_complete_position',
                             context['input'])

    def gather_candidates(self, context):
        return self.vim.call('necovim#gather_candidates',
                             context['input'],
                             context['complete_str'])
