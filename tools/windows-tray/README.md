# Bandeja do Doop no Windows

Inicia o Doop sem janela de console e coloca um ícone com o logo do Doop na bandeja do sistema.

## Instalação

Com as dependências já instaladas (`bun install`), rode uma vez:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\windows-tray\install-shortcut.ps1
```

Isso cria o atalho `Doop` na Área de Trabalho. Clicar nele sobe a API e a web e abre http://localhost:4300 quando
estiverem prontas. Se o Doop já estiver rodando, só abre o navegador.

O Windows pode esconder o ícone na seta `^` da bandeja; arraste-o de lá para deixá-lo sempre visível.

## Menu

- **Abrir Doop** (ou duplo clique): abre no navegador e sobe os servidores se estiverem parados.
- **Status**: bolinha verde ou cinza, atualizada a cada 10 s.
- **Reiniciar API**: reinicia a API e libera o Chrome aberto pelos screenshots.
- **Parar Doop e sair**: encerra a API, a web e o ícone.

No terminal, `doop-tray.ps1 -Action stop` e `-Action restart` fazem o mesmo com a bandeja em execução.

## Observações

- Roda em modo dev: API (`tsx watch`) e web (Vite) como dois processos, porque `tsx watch` trava dentro do
  `concurrently` nesta configuração. Os logs ficam em `data\`.
- **Parar** encerra os processos à força, sem o desligamento normal do servidor. Faça cópia de `data\pg` antes de
  guardar algo importante no banco embutido.
- Abra pelo atalho, não por um shell do Claude Code: esse shell define `ANTHROPIC_BASE_URL`, e uma variável herdada tem
  prioridade sobre o `.env`.
