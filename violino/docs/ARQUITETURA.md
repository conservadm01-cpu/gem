# MSAapp Violino — arquitetura

## Decisão

**Frontend** Vite + React + TypeScript · **Backend e banco** Supabase
(Postgres, Auth, RLS, Storage) · **Publicação** GitHub Pages.

O projeto pede para separar frontend, backend, banco, autenticação, arquivos,
analytics e conteúdo, e para não pôr tudo num HTML só. Pede também que a
permissão seja verificada no servidor, não só na tela.

O Supabase resolve as duas coisas sem escrever um servidor: a verificação de
permissão acontece no Postgres, a cada consulta, pelas políticas de acesso
(RLS). Um frontend adulterado não contorna isso — ele fala com a mesma API que
o banco protege. Storage guarda os vídeos com a mesma regra de acesso.

Também reaproveita o que já está de pé e testado neste repositório: o app atual
já usa Supabase com RLS por perfil, junção de progresso sem conflito e
importação de PDF.

```
navegador                     Supabase                       GitHub Pages
┌──────────────┐   HTTPS   ┌──────────────────────┐        ┌────────────┐
│ React + TS   │──────────▶│ Auth (senha, sessão) │        │ build      │
│ camada dados │──────────▶│ PostgREST → Postgres │        │ estático   │
│ (mock ↔ api) │           │   └─ RLS = permissão │        └────────────┘
│ UI           │──────────▶│ Storage (vídeos)     │
└──────────────┘           └──────────────────────┘
```

A camada de dados do frontend é uma interface só, com duas implementações:
`mock` (dados em memória, para desenvolver e demonstrar sem banco) e `api`
(Supabase). Trocar uma pela outra não toca em tela nenhuma — é o modo
demonstrativo que o projeto pede, sem virar reescrita depois.

## Estrutura de pastas

```
violino/
├─ docs/         FONTES.md (auditoria das fontes), ARQUITETURA.md
├─ dados/        matriz-pedagogica.csv · hinario-indice.csv · hinario-regras.json
├─ supabase/
│  └─ migrations/  0001 identidade · 0002 conteúdo · 0003 aprendizagem
│                  0004 indicadores · 0005 políticas
└─ app/          (frontend — próxima etapa)
   ├─ src/dados/   interface + mock + api
   ├─ src/dominio/ regras que não dependem de tela (geração, não repetição)
   ├─ src/telas/   aluno · instrutor · encarregado · administrador
   └─ src/ui/      componentes
```

## Banco de dados

**32 tabelas, 67 políticas, 19 funções, 14 tipos.** As migrações aplicam do
zero e reaplicam sem erro.

| Grupo | Tabelas |
|---|---|
| Identidade | `usuarios`, `permissoes`, `perfil_permissoes`, `usuario_permissoes`, `logs` |
| Conteúdo | `fontes`, `cursos`, `fases`, `modulos`, `licoes`, `atividades`, `questoes`, `conteudo_versoes` |
| Índices | `matriz`, `hinos`, `hinario_regras`, `metodo_topicos` |
| Turmas | `turmas`, `turma_instrutores`, `matriculas`, `liberacoes` |
| Avaliação | `modelos_avaliacao`, `avaliacoes`, `respostas`, `questoes_usadas` |
| Acompanhamento | `videos`, `criterios_video`, `video_avaliacoes`, `perguntas` |
| Reconhecimento | `medalhas`, `aluno_medalhas`, `certificados` |

Cinco decisões que atravessam o esquema:

**Senha nunca em texto puro.** Fica no `auth.users` do Supabase, verificada
pelo servidor. `usuarios` é só o cadastro.

**O papel nunca vem do formulário.** Quem se inscreve entra como ALUNO; só um
administrador promove. Aceitar um papel declarado na inscrição deixaria
qualquer visitante se nomear administrador. A primeira conta do sistema é a
exceção, para o painel não nascer trancado. A coluna `perfil` tem trava
própria num gatilho, porque política de acesso trabalha por linha e não por
coluna.

**Referência obrigatória.** `questoes.referencia` tem `check` de não vazio, e
toda questão aponta para uma `fonte`. A regra de ouro "toda questão deve
possuir referência" vira restrição de banco, não recomendação.

**Alterar não sobrescreve.** Um gatilho guarda a linha anterior inteira em
`conteudo_versoes` e sobe `versao`. O histórico de `RASCUNHO → TESTE →
APROVADO → PUBLICADO` fica legível.

**Uma linha por questão respondida.** `respostas` guarda resposta, acerto,
tempo, dificuldade, habilidade, fonte, fase e assunto. É daqui que sai todo o
resto — sem isso não há como dizer em que o aluno tropeça nem qual erro se
repete.

## Permissões

RBAC em duas camadas: a permissão vem do papel (`perfil_permissoes`), e
`usuario_permissoes` abre ou fecha exceção para uma pessoa sem mexer no papel
dela. As políticas consultam `tem_permissao(código)`, então mudar o catálogo
muda o acesso sem reescrever política.

| | ALUNO | INSTRUTOR | ENCARREGADO | ADMINISTRADOR |
|---|---|---|---|---|
| conteúdo publicado | lê | lê | lê e escreve | lê e escreve |
| conteúdo em rascunho/teste | — | lê | lê e escreve | lê e escreve |
| aprovar e publicar | — | — | sim | sim |
| turmas | a própria | as suas | todas | todas |
| desempenho | o próprio | dos seus alunos | todos | todos |
| vídeos | envia | avalia os seus alunos | avalia | avalia |
| auditoria | — | — | lê | lê |
| promover contas | — | — | — | sim |

`acompanha_aluno(id)` é quem decide o alcance do instrutor: ele enxerga o
aluno matriculado numa turma em que é instrutor, e mais ninguém.

## Indicadores

| Função | Responde |
|---|---|
| `desempenho_por_assunto` | No que ele é bom, onde tropeça |
| `desempenho_por_fonte` | Vai bem em teoria mas mal no instrumento? |
| `desempenho_por_habilidade` | Decora mas não aplica? |
| `desempenho_por_fase` | Onde o aluno está |
| `dificuldades_recorrentes` | Qual erro está se repetindo |
| `evolucao` | Ele está evoluindo? |
| `pronto_para_avancar` | Ele está pronto — e por quê |

`classificar_dominio` aplica a escala do projeto: 85+ domínio, 70–84 em
desenvolvimento, 50–69 atenção, abaixo de 50 reforço. Abaixo de 4 respostas
não classifica: errar a única questão de um assunto daria 0% e mandaria para
reforço sem razão.

## O que está testado

Num Postgres local, 18 verificações: primeira conta vira administrador e a
declaração de papel na inscrição é ignorada; aluno não se promove; RBAC por
papel; criação de conteúdo e turma; **versão teste** (aluno vê 0 rascunhos, o
revisor vê todos); publicação com versionamento; aluno respondendo; aluno não
reescreve a própria prova; os sete indicadores; **privacidade** (o instrutor
vê o aluno da turma dele e nenhum outro); vídeo e avaliação por critério;
aluno não avalia o próprio vídeo; medalha e certificado; e a trilha de
auditoria, que ninguém reescreve.

Dois defeitos foram encontrados nesse caminho e corrigidos na origem: um
`cast` de `fases.id` (texto) para inteiro em duas funções, e o `insert …
returning` do log, que no Postgres também exige política de leitura e fazia o
registro falhar justamente para o aluno.

## Funcionalidades pendentes

- Frontend (todas as telas e os quatro menus)
- Gerador de questões e a engine de não repetição no domínio
- Avaliação integrada MSA + Método + Hinário
- Jogos, recomendação, exportação JSON/CSV
- **Conteúdo do método de violino** — bloqueado, arquivo não recebido
- **Partitura de cordas e metadados dos hinos** — bloqueado, ver `FONTES.md`
