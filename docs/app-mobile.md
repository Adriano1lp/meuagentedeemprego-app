# App mobile MAE

O que o app Flutter faz nesta branch: telas, currículo, carta, cota e erros. As frases entre aspas são o texto fixo do código (muitas sem acento). O pipeline de APK continua em [`.github/firebase-app-distribution.md`](../.github/firebase-app-distribution.md).

## Telas

A entrada (`AppEntryPoint`) mostra um indicador enquanto há sessão salva. Sem sessão, abre **Entrar na conta**. Com sessão, consulta o usuário e `GET /users/me/status`, grava `hasCv` local como `has_cv` e `has_embeddings` juntos, e abre **Home** só nesse caso. Senão abre **Enviar currículo**. Se essa consulta falhar por outro motivo que não consentimento desatualizado, a sessão é limpa e volta a tela de entrada.

| Tela | O que faz |
| --- | --- |
| Entrar na conta | Abas para entrar (`POST /auth/login`) ou criar conta (`POST /auth/register`). No login, pode oferecer biometria neste aparelho. Depois do sucesso, consulta o status e segue para Home ou para o envio do currículo. Erro de autenticação vai para um SnackBar. |
| Enviar currículo | Escolhe um `.txt` ou `.pdf`, envia e pede o processamento dos embeddings. Também é o destino de atualização a partir da Home, do menu e dos gates de análise e carta. |
| Home | Atalhos: Análise de vaga, Histórico, Buscar vagas e Currículo. A carta não está na Home. |
| Análise da vaga | Campo para colar a descrição. Com embeddings prontos, envia `POST /processar` e mostra a resposta (`texto_resposta`) e, se houver, o botão do PDF (`pdf_url`). |
| Histórico | Lista análises anteriores de `GET /users/me/gap-history` (só do JWT). O texto do card junta cargo, empresa, aderência e, quando a API manda, resumo, pontos fortes e lacunas. Se `generation_blocked` vier verdadeiro, o texto inclui "PDF nao gerado." ou "PDF nao gerado: " mais `blocked_reason`. O card tem Expandir/Recolher. O botão "Abrir PDF" só aparece se a mensagem tiver `pdfUrl`; o mapeamento desse GET não preenche `pdfUrl`, então o botão não sai nessa lista. |
| Carta de apresentação | Pede o nome da empresa e, se o gate permitir, gera o PDF em `POST /users/me/cover-letter`. O menu é o caminho até esta tela. |
| Buscar vagas | Filtra no aparelho uma lista fixa de quatro vagas e abre o link externo. Não chama a API. |
| Atualizar aceites | Cobre o app quando termos ou privacidade estão desatualizados. O texto legal vem de `GET /legal/...`; o reaceite vai em `POST /consent`. |
| Menu lateral | Home, Análise de vaga, Histórico, Carta, Buscar vagas, Currículo, Sair e, se a biometria estiver ativa, Desativar biometria. |

A análise e a carta mostram a conversa em balões (`VOCE` / `AGENTE`). O horário debaixo do balão é a hora local da mensagem, no formato hora:minuto. A carta guarda esses balões só na memória da tela. A análise desta sessão fica no armazenamento local; o Histórico é outra lista, a da API.

## Currículo e `has_embeddings`

1. A pessoa escolhe um arquivo. Sem seleção, o app avisa para escolher `.txt` ou `.pdf`. Se não conseguir ler o arquivo, avisa isso e não chama a API.
2. `POST /users/me/upload-cv` envia o arquivo no campo `file`.
3. Em seguida, `POST /users/me/rebuild-embeddings` roda sem corpo.
4. Se os dois retornam 200 ou 201, o app marca `hasCv` local como verdadeiro, mostra o SnackBar "Curriculo enviado e processado com sucesso." e vai para a Home. Essa marca local não relê o status.

O sinal que libera análise e carta é outro. Em `GET /users/me/status`, `has_cv` e `has_embeddings` só contam como verdadeiros com `== true` no JSON. Qualquer outro valor conta como falso.

- Análise (`AnalyzeGate.canAnalyze`) e carta (`CoverLetterGate.canGenerate`) exigem apenas `has_embeddings == true`. Currículo presente sem embeddings não libera.
- A rota inicial usa os dois: Home só com `has_cv` e `has_embeddings`. Com currículo ainda sem embeddings, a entrada manda para **Enviar currículo**.

Na análise, a mensagem muda conforme o status:

- status ainda nulo: "Aguarde o status do curriculo para analisar a vaga." (a tela de análise também usa essa frase na dica quando a consulta falha; o SnackBar é que traz o erro)
- sem currículo: "Sem curriculo valido. Envie um PDF ou TXT para habilitar Analisar vaga."
- com currículo e sem embeddings: "Embeddings ainda nao estao prontos. Envie o curriculo e aguarde o processamento."

Abrir Análise de vaga sem embeddings mostra a frase correspondente num SnackBar e abre **Enviar currículo**, sem entrar no chat. Se a pessoa já está na tela de análise e o status volta sem embeddings, a faixa amarela repete a frase e o botão "Enviar curriculo" abre o mesmo envio; ao voltar, o status é consultado de novo. Texto curto ou sem sinais de vaga não chama `POST /processar`; o SnackBar pede uma descrição com cargo, requisitos ou responsabilidades.

## Carta

Ao abrir, a tela consulta `GET /users/me/status` (o mesmo leitor da análise). Enquanto isso, o campo fica desligado, o botão diz "Verificando" e a dica é "Verificando curriculo e embeddings...".

**Gate, antes de gerar.** O botão "Gerar carta" só liga com `has_embeddings == true`, fora de carga e fora da consulta. Sem isso, uma faixa amarela aparece:

- status ok, mas sem embeddings (com ou sem currículo): "Envie ou atualize o curriculo para gerar a carta." O botão "Enviar ou atualizar curriculo" abre **Enviar currículo** e, ao voltar, consulta o status de novo.
- a consulta de status falhou: "Nao foi possivel verificar o curriculo. Tente novamente." Se a exceção tiver texto, ele é acrescentado na mesma frase. O botão "Tentar novamente" repete o `GET`.

A carta não separa "sem currículo" de "sem embeddings". As duas situações usam a mesma frase de atualizar o currículo. A análise, descrita acima, separa.

**Geração.** O corpo é só `{"empresa": "<nome digitado>"}`. Nome vazio: SnackBar "Informe o nome da empresa." Sem token: "Sessao expirada. Entre novamente." Antes do POST a tela consulta o status outra vez; se o gate fechar, não envia.

Durante o POST o botão mostra "Gerando" e o subtítulo "Processando /users/me/cover-letter". A dica diz que a API está gerando a carta e preparando o PDF. O nome digitado entra como balão do usuário.

**O que a tela mostra no sucesso (200 ou 201).** Um balão do agente com `texto_resposta`. Se esse campo vier vazio, o texto fixo é "Carta gerada sem texto de resposta." Se `pdf_url` for uma URL absoluta, o balão ganha "Abrir PDF". O campo da empresa é limpo. A tela vazia, antes de qualquer mensagem, diz "Gere uma carta em PDF" e explica que o nome da empresa usa o contexto do currículo.

O app não contém o literal `[data atual]` e não grava data no corpo da carta: o balão mostra `texto_resposta` como a API devolveu. O horário sob o balão é só o relógio local da mensagem.

## Cota (402)

Não há tela, contador nem texto fixo de cota. O 402 não tem ramo próprio.

`POST /users/me/cover-letter` que responde 402 cai em `rethrowApiError`. A tela tira o prefixo `Exception: `, mostra o resultado num SnackBar de 8 segundos e encerra o spinner. O balão do agente não é criado. O nome da empresa permanece no campo. Se o último status ainda tiver embeddings, "Gerar carta" volta a ficar disponível.

O mesmo formatador vale para upload, rebuild, `POST /processar` e autenticação quando o Dio recebe um 402. O histórico não usa esse formatador.

## Estados de erro

O texto vem de um destes lugares. O app não inventa a frase da cota nem cola corpo de currículo ou de carta.

| Origem | Forma na tela |
| --- | --- |
| `detail` da API (FastAPI) | String em `detail`; ou `detail.message`; ou, numa lista de validação, o primeiro `msg` ou `message`. Carta, análise, currículo e login prefixam `HTTP <código>: `. |
| Frase fixa do app | Gates, validação local, timeouts e falhas sem `detail`. |
| Exceção já montada | A tela mostra `toString()` sem o prefixo `Exception: `. |
| Histórico | Não mostra `detail`, URL, caminho nem token. Usa frases fixas, salvo consentimento desatualizado, que usa a mensagem da exceção. |
| Download do PDF | Se o corpo for um mapa com `detail` string, mostra essa string crua, sem prefixo `HTTP`. Senão, "Nao foi possivel baixar o PDF autenticado." ou "Nao foi possivel abrir o PDF." |

**402.** SnackBar `HTTP 402: ` mais o `detail` acima (em geral `detail.message`). Não há outro estado visual de cota.

**422.** O mesmo caminho, com prefixo `HTTP 422: `. String de `detail`, ou a primeira mensagem da lista de validação. Na carta, também é SnackBar e o spinner para.

**Falha de status.** Na carta, a faixa amarela junta a frase fixa de tentar de novo com o texto da exceção (por exemplo `HTTP <código>: ` mais `detail`, ou o fallback "Falha ao autenticar com a API" quando o status não traz `detail`). O botão "Tentar novamente" refaz o `GET`. Na análise, falha de status não marca "sem embeddings": o campo fica desligado, a dica usa "Aguarde o status do curriculo para analisar a vaga." e o SnackBar mostra a exceção. Não há botão de retry nessa tela; sair e entrar de novo dispara outra consulta, porque a tela consulta o status ao abrir.

**Sem embeddings.** Carta: faixa "Envie ou atualize o curriculo para gerar a carta." e atalho para o envio. Análise: as três frases da seção do currículo, SnackBar na navegação e faixa "Enviar curriculo" se a pessoa já estiver na tela. `has_embeddings` falso bloqueia mesmo com `has_cv` verdadeiro.

**Erro recuperável.** 402, 422 e as outras falhas do POST da carta não travam a tela: o SnackBar aparece, o spinner some e dá para gerar de novo se o gate continuar aberto. Falha de status na carta recupera com "Tentar novamente". Falha no envio do currículo volta o botão, grava na faixa "Falha no envio do curriculo." e mostra no SnackBar a mensagem da API ou a frase local; dá para escolher o arquivo e enviar outra vez. No histórico, o erro zera a lista: o estado vazio repete um título fixo e, no corpo, a frase segura ("Entre na sua conta para ver o historico.", "Sessao expirada. Entre novamente para ver o historico." ou "Nao foi possivel carregar o historico. Tente novamente."). "Tentar novamente" refaz o `GET`.

Outros textos fixos do mesmo formatador, quando não há `detail`: tempo de recebimento ou envio esgotado vira "A analise demorou demais. Tente novamente."; tempo de conexão, "Tempo de conexao esgotado"; falha de conexão, "Nao foi possivel alcancar a API" e, se a base estiver configurada, o endereço usado. HTTP sem `detail` usa o fallback da chamada (carta: "Falha ao gerar carta de apresentacao"; upload: "Falha ao enviar curriculo"; rebuild: "Falha ao processar curriculo"; análise: "Falha ao conectar com a API") no formato `HTTP <código>: <fallback>`. 404 sem `detail` vira "HTTP 404: Endpoint nao encontrado".

Consentimento desatualizado (403 com código de termos ou privacidade) não segue esse SnackBar como estado final: o app abre **Atualizar aceites** por cima e bloqueia o resto até o reaceite.
