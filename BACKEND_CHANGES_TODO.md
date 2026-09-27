# Mudanças de backend — validações necessárias nos apps

> Origem: sessão de correções de concorrência + hardening de segurança/disponibilidade no backend, branch `hotfix-login` (2026-09-17). Ainda **não está em produção**. Este documento é o mesmo nos dois apps (`moto_driver` e `moto_passenger`) — cada um trata só a sua seção.
>
> Detalhe completo das mudanças de backend: `CONTEXTO-MOTO.md` (repo `moto_backend`), seção §13.

---

## 🔴 Precisa de validação/código novo

### [Motorista + Passageiro] Rate limit de reset de senha agora vem com mensagem

**O que mudou:** os dois limites de tentativa no fluxo de reset de senha (já existiam, só faltava o corpo da resposta) agora devolvem mensagem clara:

**1. Errar o código de verificação 5x seguidas (30 min) — `POST /api/auth/password-reset/verify-code`:**
```
HTTP 429 Too Many Requests
{"error": "Muitas tentativas com código incorreto. Aguarde 30 minutos e peça um novo código."}
```

**2. Pedir reset de senha demais (`POST /api/auth/password-reset/request`, por e-mail ou por IP):**
```
HTTP 429 Too Many Requests
{"error": "Muitas solicitações de redefinição de senha. Aguarde um pouco antes de tentar novamente."}
```

Antes, os dois vinham `429` **sem corpo nenhum** — o app não tinha como mostrar nada além de erro genérico.

**O que fazer:**
- [x] Tratar `429` nesses dois endpoints mostrando a mensagem do corpo (já pronta em português).
- [x] Não incluímos tempo de espera na mensagem de propósito (decisão consciente, não esquecimento) — não precisa de countdown/timer na tela, só uma mensagem estática.

### [Motorista + Passageiro] Login e reset de senha em conta ainda não aprovada agora dão mensagem clara

**O que mudou:** achamos um bug real testando o checklist manual — dava pra **resetar a senha de uma conta que ainda nem foi aprovada** pelo GlobalAdmin (cadastro pendente). O reset "funcionava", mas o login continuava recusando do mesmo jeito que senha errada — muito confuso pra quem tava testando. Corrigido nos dois pontos:

**1. `POST /api/auth/sign-in` em conta pendente de aprovação:**
```
HTTP 401 Unauthorized
{"error": "Sua conta ainda não foi aprovada. Aguarde a aprovação de um administrador ou entre em contato com o suporte."}
```
Antes vinha `401` **sem corpo nenhum** — igual erro de senha errada. Agora vem com mensagem, mas o status continua `401` (pra não mudar o fluxo de "senha inválida" que o app já trata).

**2. `POST /api/auth/password-reset/request` em conta pendente de aprovação:**
```
HTTP 403 Forbidden
{"error": "Sua conta ainda não foi aprovada. Aguarde a aprovação de um administrador antes de redefinir a senha."}
```
Antes, o reset seguia normal (bug) mesmo a conta nunca tendo sido aprovada.

**Importante — login com senha errada em conta normal continua igual** (`401` sem corpo, sem mensagem) — só quem tem cadastro pendente vê a mensagem nova. Não precisa mudar o tratamento de "senha incorreta" que já existe, só adicionar o caso novo.

**O que fazer:**
- [x] Na tela de login: se vier `401` **com corpo** (`{"error": "..."}`) contendo essa mensagem específica, mostrar ela em vez do "e-mail ou senha incorretos" genérico — orienta melhor quem acabou de se cadastrar e ainda não foi aprovado.
- [x] Na tela de reset de senha: tratar `403` no `/request` mostrando a mensagem do corpo (já pronta em português).

---

### [Motorista] `POST /api/travels/orders/{orderId}/accept` agora pode devolver `403 Forbidden`

**O que mudou:** antes, era possível (bug) um motorista aceitar uma corrida mesmo sem ser mais o alvo da oferta atual — por exemplo, se a oferta já tivesse passado pro próximo motorista da fila (timeout de 20s) mas o app do motorista anterior ainda mostrasse o card por atraso de rede/push. Isso foi corrigido no backend: agora esse aceite é bloqueado.

**Resposta nova:**
```
HTTP 403 Forbidden
```
Sem corpo JSON (é um `Results.Forbid()` puro — status apenas, sem `{"error": ...}`).

**Cenário em que isso vai acontecer de verdade (não é edge case raro):** motorista recebe a oferta, demora pra responder, o timeout de 20s passa a oferta pro próximo motorista da fila — e *nesse meio-tempo* o motorista original aperta "aceitar". Isso é fluxo normal de disputa entre motoristas, não erro de app.

**O que fazer:**
- [ ] Tratar `403` especificamente na tela de oferta de corrida (`IncomingOrderSheet` ou equivalente).
- [ ] Mostrar mensagem amigável tipo *"Essa corrida não está mais disponível"* em vez de erro genérico/crash.
- [ ] Fechar o card da oferta automaticamente e voltar o motorista pro estado "aguardando corrida".
- [ ] Não tentar re-enviar o accept em retry automático nesse caso específico (é definitivo, não transitório).

---

### [Passageiro] `POST /api/travels/orders` e `POST /api/travels/priority-orders` agora têm rate limit

**O que mudou:** novo limite de **10 pedidos de corrida por passageiro a cada 5 minutos**. Antes não existia nenhum limite — nada impedia loop acidental (ou intencional) de criação de pedidos.

**Resposta nova:**
```
HTTP 429 Too Many Requests
{"error": "Muitos pedidos de corrida em pouco tempo. Aguarde alguns minutos e tente novamente."}
```

**O que fazer:**
- [ ] Tratar `429` mostrando a mensagem que vem no corpo da resposta (já pronta em português, pode exibir direto).
- [ ] **Auditar qualquer retry automático** existente no fluxo de criação de corrida (`ConfirmTravel`/`NewTravelPage` ou equivalente) — se houver reenvio silencioso em caso de falha de rede/timeout, garantir que ele não vira um loop que esbarra nesse limite sozinho.
- [ ] Cancelar + pedir de novo repetidamente (ex: usuário testando endereços diferentes rapidamente) é uso legítimo dentro do limite — não precisa mudar esse fluxo, só garantir que o app não solicita a corrida mais de uma vez por toque do usuário.

---

### [Passageiro] Validação de coordenadas agora retorna erro correto

**O que mudou:** antes, uma coordenada fora do range válido (latitude fora de -90..90, longitude fora de -180..180 — ex: GPS retornando `0,0` ou valor não inicializado) ia direto pro Google Maps e voltava como `503 Service Unavailable` com uma mensagem de exceção crua do .NET (parecia "servidor fora do ar"). Agora é validado antes, com erro correto.

**Resposta nova:**
```
HTTP 400 Bad Request
{"error": "Coordenadas de embarque inválidas."}   // ou "Coordenadas de destino inválidas."
```

**O que fazer:**
- [ ] Se o app tiver algum tratamento que trata `503` na criação de corrida como "backend fora do ar" (ex: banner de "sem conexão com o servidor"), **separar esse caso do `400`** — `400` significa que o GPS do próprio dispositivo mandou coordenada inválida, o usuário deveria ver algo tipo *"Não foi possível obter sua localização, tente novamente"*, não uma mensagem de indisponibilidade do servidor.
- [ ] Isso não deveria acontecer em uso normal — é uma rede de segurança. Se aparecer com frequência em produção, é sinal de bug no `LocationService`/GPS do próprio app.

---

## 🟡 Bom saber — não deveria exigir mudança de código, mas vale conferir

### `/api/routes/*` agora exige autenticação

Autocomplete de endereço (`GET /api/routes/coordinates`) e cálculo de rota (`POST /api/routes/details`) — usados na tela "Nova Viagem" do app passageiro — agora exigem token válido. Antes eram públicos (sem autenticação nenhuma).

- [ ] **Confirmar que nenhuma tela do app chama esses endpoints antes do login completo** (ex: alguma preview/demo sem estar autenticado). Já testei o fluxo normal (usuário logado) e o `Dio`/`AuthInterceptor` do app já manda o token em toda chamada — não deveria quebrar nada no uso comum.

### Reconexão do SignalR

Confirmado em teste real: uma queda de rede breve (poucos segundos) muitas vezes nem chega a derrubar o WebSocket de verdade — o hub continua "conectado" o tempo todo sem perceber a instabilidade. Quando cai de verdade e reconecta, o backend **não reenvia** ofertas/eventos já entregues antes (evita duplicidade proposital).

- [ ] Não é preciso mudar nada agora, mas se o app tiver alguma lógica de "ao reconectar, buscar estado do zero", isso continua funcionando — só documentando o comportamento pra quem for mexer nessa área depois.

---

## 🟢 Não afeta o app — informativo

- Correções de concorrência no despacho (oferta duplicada pro mesmo motorista, motorista "fantasma" preso na janela do timeout de 20s) — 100% interno, backend. Resultado prático pro app: o fluxo de despacho fica mais confiável, sem mudança de contrato de API.
- Limite de conexões com banco, teste de múltiplas instâncias, carga sustentada — infraestrutura, sem impacto em client.

---

## Contato

Dúvida sobre qualquer item acima, procurar o Igor ou consultar `CONTEXTO-MOTO.md` §13 no repo `moto_backend` pro detalhe técnico completo de cada mudança (inclusive os testes que comprovaram cada comportamento).
