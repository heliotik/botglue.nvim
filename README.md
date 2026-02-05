# Neovim-плагин для оптимизации промтов через Claude Code CLI

## Описание проекта

**botglue.nvim** — плагин для Neovim, который позволяет улучшать промты и исследовать код с помощью Claude Code CLI. Работает в режиме "one-shot": выделяешь текст → вводишь промт → получаешь результат.

## Ключевые требования

### Функциональность
- **One-shot режим**: плагин принимает выделенный текст, отправляет его в Claude Code CLI с заданным системным промтом, возвращает результат
- **Интеграция с Claude Code**: использует `claude` CLI для обработки текста (не API, именно CLI-инструмент)
- **Визуальный режим**: работа с выделенным текстом в Neovim (visual mode selection)

### Архитектура (по образцу ThePrimeagen/99)
- Референсный проект: https://github.com/ThePrimeagen/99
- Локальный форк для изучения: `/home/heliotik/project/heliotik/300`
- Перенять паттерны: структуру плагина, способ вызова внешних CLI, обработку выделения, окно ввода промта

### Техническая реализация
- Язык: Lua (стандарт для Neovim-плагинов)
- Точка входа: `prompt-optimizer.lua`
- Использовать Neovim API (`vim.*`) для работы с буферами, выделением, командами

## Текущее состояние

- Начальная реализация: `botglue.nvim/prompt-optimizer.lua`
- Конфигурация MCP: `prompt-optimizer-mcp.json`

## Структура проекта

```
botglue.nvim/
├── prompt-optimizer.lua    # основной модуль плагина
├── prompt-optimizer-mcp.json
└── README.md
```

## Вдохновение

- [ThePrimeagen/99](https://github.com/ThePrimeagen/99) — паттерны интеграции CLI с Neovim
- шаблон для создания плагина https://github.com/ellisonleao/nvim-plugin-templatek

## Описание плагина ThePrimeagen/99

Плагин 99 — это AI‑агент внутри Neovim, который работает поверх OpenCode и ограничен текущим проектом/буфером, а не «всем компьютером». [byteiota](https://byteiota.com/theprimeagens-99-hits-542-stars-day-ai-for-skilled-devs/)

## Общая идея взаимодействия

Пользователь остаётся в своём обычном Vim‑флоу (LSP, treesitter, свои keymaps) и время от времени «врезает» AI туда, где нужно: дополнить функцию, переписать выделенный блок, помочь с конкретным файлом. [dev](https://dev.to/pacheco/the-developer-identity-crisis-ap2)
Философия: AI — это инструмент для **точечных** операций (заполнение, правка, объяснение конкретного куска), а не автономный агент, который бродит по проекту сам. [x](https://x.com/ThePrimeagen/status/2006382336527520236)

## Шаги установки и подготовки

- Пользователь ставит OpenCode и настраивает провайдера моделей (Claude, OpenAI и т.п.) — именно он выполняет все AI‑запросы. [github](https://github.com/ThePrimeagen/99/blob/master/README.md)
- Устанавливает 99 как Lua‑плагин (через lazy.nvim или другой менеджер), подключая его к уже существующей экосистеме: treesitter, LSP. [trendshift](https://trendshift.io/repositories/19461)
- В корне проекта (или в отдельных папках) создаёт AGENT.md, где описывает правила, стиль кода, доменную специфику — это «личность» и правила агента для этого репо. [github](https://github.com/ThePrimeagen/99/blob/master/AGENTS.md)

## Базовые сценарии в редакторе

Типичный UX выглядит так:

- Пользователь редактирует код, как обычно, и доходит до места, где нужно реализовать функцию или кусок логики.  
- Вызывает команду 99 (через :команду или keymap), находясь курсором внутри функции‑заглушки — плагин формирует промпт из текущего буфера, окружающего кода и AGENT.md, отправляет в OpenCode, и возвращает уже заполненную/переписанную функцию. [byteiota](https://byteiota.com/theprimeagens-99-hits-542-stars-day-ai-for-skilled-devs/)
- Если нужно изменить существующий код, пользователь выделяет визуальный блок и снова вызывает соответствующую команду 99 — агент получает только этот фрагмент плюс ограниченный контекст, предлагает правку, которую плагин применяет как патч. [reddit](https://www.reddit.com/r/theprimeagen/comments/1qs403e/didnt_get_the_idea_behind_99_prompt_plugin/)

Это ощущается как «inline‑редактирование» в стиле Cursor, но в Neovim и без постоянных автоподсказок. [reddit](https://www.reddit.com/r/theprimeagen/comments/1qs403e/didnt_get_the_idea_behind_99_prompt_plugin/)

## Работа с правилами и «скиллами»

- Через AGENT.md пользователь задаёт проектные правила: стиль, архитектурные ограничения, запрещённые решения, важные инварианты. [github](https://github.com/ThePrimeagen/99/blob/master/AGENTS.md)
- Внутри промпт‑бокса (UI 99) используются специальные конструкции (например, префиксы вида @), которыми пользователь подключает заранее описанные «skills» / поведения, влияющие на то, как агент решает задачу. [byteiota](https://byteiota.com/theprimeagens-99-hits-542-stars-day-ai-for-skilled-devs/)
- Это даёт эффект «шаблонных действий»: можно быстро включать, например, режим «пиши только тесты», «делай рефакторинг без изменения публичного API» и т.п., не расписывая каждый раз полный промпт. [byteiota](https://byteiota.com/theprimeagens-99-hits-542-stars-day-ai-for-skilled-devs/)

## Как это ощущается в повседневной работе

- Пользователь почти не меняет привычные привычки: двигается по коду, использует LSP‑goto, diagnostics, а 99 включается по горячей клавише там, где надо ускориться. [dev](https://dev.to/pacheco/the-developer-identity-crisis-ap2)
- В отличие от «виб‑кодинга» с большими агентами, пользователь сам решает, какой кусок кода отдавать модели и когда остановиться; 99 не лезет в другие файлы, пока его явно не попросили. [x](https://x.com/ThePrimeagen/status/2006382336527520236)
- За счёт AGENT.md и skills команда разработки может стандартизировать поведение AI: разные люди вызывают 99, но получают решения в одном стиле и в рамках общих правил проекта. [github](https://github.com/ThePrimeagen/99/blob/master/AGENTS.md)

# План от перплексити

## 1. Пользовательский сценарий (UX)

1. Visual‑выделение кода в любом буфере.  
2. Нажатие хоткея (например, `<leader>op`) → открывается минимальное prompt‑окно (float или `vim.ui.input`).  
3. Пользователь вводит простой промт (например, «оптимизируй промт под Claude Code», «перепиши как system prompt»).  
4. Плагин собирает: системный промт (из файла / конфига), пользовательский промт, выделенный текст → дергает `claude` CLI в non‑interactive режиме. [platform.claude](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompt-improver)
5. Результат либо:
   - заменяет выделенный текст,  
   - вставляется в новый сплит/буфер (режим «preview»),  
   - копируется в регистр/clipboard.  

На первом этапе можно сделать только «заменить выделенное» + опциональный просмотр через `vim.notify`. [perplexity](https://www.perplexity.ai/search/e0bbb433-b42a-4841-bce1-862c411605cb)

## 2. Архитектура плагина

Опираемся на 3 слоя (по мотивам 99 и `nvim-plugin-template`): [github](https://github.com/ThePrimeagen/99)

1. **UI‑слой** (prompt‑окно, команды, keymaps)  
   - Модуль `botglue.ui` (или прямо в `prompt-optimizer.lua` на старте).  
   - Использовать `vim.ui.input` или свой float (позже можно заменить на `noice.nvim`/`snacks` интеграцию).  

2. **Core‑слой** (работа с выделением и буферами)  
   - Функции: `get_visual_selection()`, `replace_visual_selection(text)`, `open_output_split(text)`.  
   - Работа только через `vim.api.nvim_buf_get_text`, `vim.api.nvim_buf_set_text`, `vim.fn.getpos("'<")`.  

3. **CLI‑адаптер** (обертка над Claude Code CLI)  
   - Модуль `botglue.claude_cli` с функцией:  
     ```lua
     M.run(opts) -- { prompt, system_prompt, input_text } -> callback(result)
     ```  
   - Использовать `vim.system({ "claude", ... }, { text = true, stdin = input_text }, cb)`; на старте можно синхронно через `vim.fn.system()` для MVP. [arize](https://arize.com/blog/claude-md-best-practices-learned-from-optimizing-claude-code-with-prompt-learning/)

Файл‑структура в духе `nvim-plugin-template`: [github](https://github.com/ellisonleao/nvim-plugin-template)

```text
lua/
  botglue/
    prompt_optimizer.lua   -- основной модуль
    core.lua               -- выборка/вставка текста
    cli.lua                -- работа с claude CLI
    config.lua             -- system prompt, настройки CLI
plugin/
  botglue.lua              -- регистрация команд и keymaps
prompt-optimizer-mcp.json  -- MCP-конфиг (позже)
README.md
```

## 3. Первый инкремент (MVP)

Цель: один рабочий happy‑path без лишнего UI. [perplexity](https://www.perplexity.ai/search/e0bbb433-b42a-4841-bce1-862c411605cb)

1. **Core: выборка и замена**

   - Реализовать `get_visual_selection()` и `replace_visual_selection(new_text)`.  
   - Сначала считать только `v` и `V` режимы, без block‑selection.  

2. **CLI‑вызов**

   - Хардкод: `CLAUDE_BIN = "claude"`; позже вынести в конфиг.  
   - Вариант вызова (пример):

     ```lua
     local cmd = {
       CLAUDE_BIN,
       "code",
       "--append-system-prompt", system_prompt,
       "--output-format", "text",
       "--mode", "non-interactive",
     }
     vim.system(cmd, { text = true, stdin = full_prompt }, function(res)
       -- res.stdout -> результат
     end)
     ```

     Детали флагов подровняем под реальную CLI‑схему (по аналогии с prompt‑optimizer hook’ами и `--append-system-prompt`). [github](https://github.com/johnpsasser/claude-code-prompt-optimizer)

3. **Команда/функция**

   - В `prompt-optimizer.lua`:

     ```lua
     function M.optimize_selection()
       local sel = core.get_visual_selection()
       if not sel or sel == "" then return end

       vim.ui.input({ prompt = "botglue prompt: " }, function(user_prompt)
         if not user_prompt or user_prompt == "" then return end
         cli.run({
           prompt = user_prompt,
           system_prompt = config.get_system_prompt(),
           input_text = sel,
           on_result = function(out)
             core.replace_visual_selection(out)
           end,
         })
       end)
     end
     ```

   - В `plugin/botglue.lua`: команда `:BotglueOptimize` + mapping `<leader>op` в visual‑режиме.  

## 4. Конфиг и системный промт

Хочется сразу заложить идею «оптимизировать промт, а не код». [github](https://github.com/johnpsasser/claude-code-prompt-optimizer)

1. **config.lua**

   - Опции:
     - `system_prompt` (строка или функция, читающая файл).  
     - `claude_bin` (путь к CLI).  
     - `strategy` (replace / split / yank).  

   - `setup(opts)` с merge по таблице.

2. **Файл с правилами**

   Варианты:

   - `prompt-optimizer-mcp.json`: хранить там MCP‑настройки + массив правил/стилей.  
   - Либо `CLAUDE_PROMPT.md`/`BOTGLUE.md` по аналогии с `AGENT.md` в 99, чтобы Claude Code уже был натренирован на эти правила. [github](https://github.com/ThePrimeagen/99/blob/master/AGENTS.md)

   На первом шаге: просто обычная строка в `config.lua` с базовым системным промтом «ты помощник, который переписывает промты для Claude Code…».

## 5. Расширения после MVP

Когда базовый one‑shot работает: [byteiota](https://byteiota.com/theprimeagens-99-hits-542-stars-day-ai-for-skilled-devs/)

1. **Режимы применения результата**

   - `replace` (по умолчанию).  
   - `preview_split` — открыть новый вертикальный сплит с результатом.  
   - `copy_only` — положить в unnamed/`+` регистр без изменения буфера.  

2. **Шаблоны промтов**

   - Простая таблица в конфиге:  
     ```lua
     templates = {
       optimize = "Оптимизируй этот промт для Claude Code",
       system = "Сделай из этого хороший system prompt",
       explain = "Объясни как работает этот промт",
     }
     ```  
   - Команда `:BotglueTemplate` с `vim.ui.select`, либо keymaps типа `<leader>oo` (optimize), `<leader>os` (system).  

3. **Интеграция с MCP / Claude Code hook’ами**

   - Связать `prompt-optimizer-mcp.json` с тем, как Claude Code CLI подхватывает system prompt/skills (по мотивам prompt‑optimizer hook и `--append-system-prompt`). [arize](https://arize.com/blog/claude-md-best-practices-learned-from-optimizing-claude-code-with-prompt-learning/)
   - Опционально: сделать режим «генерируй новый system prompt и автоматически обнови MCP‑файл».  

4. **Более «99‑подобный» UX**

   - Добавить небольшой float‑prompt в стиле 99 (окно посередине, история последних промтов). [reddit](https://www.reddit.com/r/theprimeagen/comments/1qs403e/didnt_get_the_idea_behind_99_prompt_plugin/)
   - Вынести контекст (имя файла, язык, путь к проекту) в промт, как это делает 99 через AGENT.md. [github](https://github.com/ThePrimeagen/99/blob/master/AGENTS.md)

## 6. Практические next steps для тебя

Предлагаю такой порядок:

1) В `botglue.nvim/prompt-optimizer.lua` выпилить всё лишнее и сделать один экспортируемый метод `optimize_selection()` по схеме из MVP.  
2) Вынести в отдельные модули `core.lua` и `cli.lua`, даже если внутри по 20 строк — для будущего роста.  
3) Жёстко захардкодить простейший system prompt и вызов `claude` CLI, пока не трогаешь MCP/JSON.  
4) После первого «оно работает» — вернуться и решить:
   - какие режимы результата тебе реально нужны,  
   - нужен ли отдельный файл с правилами (CLAUDE_PROMPT.md / MCP),  
   - насколько хочется походить на 99 по UI (float, шаблоны, AGENT‑style правила).  

Если хочешь, в следующем шаге могу:  
- набросать конкретные сигнатуры модулей `core.lua` и `cli.lua`,  
- придумать текст первого системного промта, заточенного под «оптимизатор промтов для Claude Code CLI».

## Другие плагины для исследования 

- [carlos-algms/agentic.nvim](https://github.com/carlos-algms/agentic.nvim) - Chat interface for AI ACP providers such as Claude, Gemini, Codex, OpenCode and Cursor.
- [blob42/codegpt-ng.nvim](https://github.com/blob42/codegpt-ng.nvim) - Minimalist command based AI coding with a powerful template system. Supports Ollama, OpenAI and more.
- [Aaronik/GPTModels.nvim](https://github.com/Aaronik/GPTModels.nvim) - GPTModels - a stable, clean, multi model, window based LLM AI tool.
- [Robitx/gp.nvim](https://github.com/Robitx/gp.nvim) - ChatGPT like sessions and instructable text/code operations in your favorite editor.
- [jackMort/ChatGPT.nvim](https://github.com/jackMort/ChatGPT.nvim) - Effortless Natural Language Generation with OpenAI's ChatGPT API.
- [CamdenClark/flyboy](https://github.com/CamdenClark/flyboy) - Simple interaction with ChatGPT in a Markdown buffer. Supports GPT-4 and Azure OpenAI.
- [gsuuon/model.nvim](https://github.com/gsuuon/model.nvim) - Integrate LLMs via a prompt builder interface. Multi-providers including OpenAI (+ compatibles), `PaLM`, `Hugging Face`, and local engines like `llamacpp`.
- [dense-analysis/neural](https://github.com/dense-analysis/neural) - Integrate LLMs for generating code, interacting with chat bots, and more.
- [jpmcb/nvim-llama](https://github.com/jpmcb/nvim-llama) - LLM (LLaMA 2 and `llama.cpp`) wrappers.
- [David-Kunz/gen.nvim](https://github.com/David-Kunz/gen.nvim) - Generate text using LLMs (via Ollama) with customizable prompts.
- [kiddos/gemini.nvim](https://github.com/kiddos/gemini.nvim) - Bindings to Google Gemini API.
- [olimorris/codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim) - Copilot Chat like experience, complete with inline assistant. Supports Anthropic, Gemini, Ollama and OpenAI.
- [you-n-g/simplegpt.nvim](https://github.com/you-n-g/simplegpt.nvim) - Provide a simple yet flexible way to construct and send questions to ChatGPT.
- [Exafunction/windsurf.nvim](https://github.com/Exafunction/windsurf.nvim) - Free, ultrafast Copilot alternative. Supports LSP and Tree-sitter.
- [GeorgesAlkhouri/nvim-aider](https://github.com/GeorgesAlkhouri/nvim-aider) - Seamlessly integrate Aider for an AI-assisted coding experience.
- [CopilotC-Nvim/CopilotChat.nvim](https://github.com/CopilotC-Nvim/CopilotChat.nvim) - A chat interface for GitHub Copilot that allows you to directly ask and receive answers to coding-related questions.
- [tzachar/cmp-ai](https://github.com/tzachar/cmp-ai) - This is a general purpose AI source for nvim-cmp, easily adapted to any REST API supporting remote code completion.
- [milanglacier/minuet-ai.nvim](https://github.com/milanglacier/minuet-ai.nvim) - Minuet offers code completion from LLM providers including OpenAI (compatible), Gemini, Claude, Ollama, Deepseek and more providers, with support for nvim-cmp, blink.cmp and virtual-text frontend.
- [yetone/avante.nvim](https://github.com/yetone/avante.nvim) - Chat with your code as if you are in Cursor AI IDE.
- [Kurama622/llm.nvim](https://github.com/Kurama622/llm.nvim) - Free large language model (LLM) support, provides commands to interact with LLM.
- [3v0k4/exit.nvim](https://github.com/3v0k4/exit.nvim) - Prompt LLMs (large language models) to write Vim commands.
- [k2589/LLuMinate.nvim](https://github.com/k2589/lluminate.nvim) - Enrich context for LLM with LSP hover added to clipboard.
- [milanglacier/yarepl.nvim#aider-extensions](https://github.com/milanglacier/yarepl.nvim/blob/main/extensions/README.md) - Integration with [aider-chat](https://aider.chat), a TUI AI coding assistant.
- [Davidyz/VectorCode](https://github.com/davidyz/vectorcode) - Supercharge your LLM experience with repository-level RAG.
- [dlants/magenta.nvim](https://github.com/dlants/magenta.nvim) - Leverage coding assistants for chat and code generation. Provides tools for the AI/LLM agent to explore and edit your code, like Aider, Cursor and Windsurf.
- [Flemma-Dev/flemma.nvim](https://github.com/Flemma-Dev/flemma.nvim) - A first-class AI workspace.
- [heilgar/nochat.nvim](https://github.com/heilgar/nochat.nvim) - Cursor-like effortless natural language generation with multiple AI providers including Ollama, Anthropic (Claude), and ChatGPT.
- [julwrites/llm-nvim](https://github.com/julwrites/llm-nvim) - Comprehensive integration with the [LLM](https://github.com/simonw/llm) tool.
- [azorng/goose.nvim](https://github.com/azorng/goose.nvim) - Seamless integration with [goose](https://block.github.io/goose) - work with a powerful AI agent without leaving your editor.
- [mozanunal/sllm.nvim](https://github.com/mozanunal/sllm.nvim) - In-editor chat powered by Simon Willison's LLM CLI: stream replies in a Markdown buffer, manage rich context (files, URLs, selections, diagnostics, shell outputs), switch models interactively, and even see token-usage stats.
- [chatvim/chatvim.nvim](https://github.com/chatvim/chatvim.nvim) - Chat with Markdown files using AI models from xAI, OpenAI and Anthropic.
- [3ZsForInsomnia/code-companion-picker](https://github.com/3ZsForInsomnia/code-companion-picker) - Telescope and Snacks picker integrations for previewing CodeCompanion prompts.
- [3ZsForInsomnia/vs-code-companion](https://github.com/3ZsForInsomnia/vs-code-companion) - Tool for importing VSCode's Markdown prompts into CodeCompanion.
- [3ZsForInsomnia/token-count.nvim](https://github.com/3ZsForInsomnia/token-count.nvim) - Shows the token count for the current buffer, with integrations for Lualine and NeoTree.
- [nishu-murmu/cursor-inline](https://github.com/nishu-murmu/cursor-inline) - Cursor-style inline AI editing. Select code, describe the change, and get an inline, highlighted edit you can accept or reject—similar to Cursor inline workflow.
- [codex.nvim](https://github.com/ishiooon/codex.nvim) - Codex IDE integration inside Neovim (no API key required).


