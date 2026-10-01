# Relatório de Auditoria Técnica — App Passageiro (moto_passenger)

Subagente 03 — Auditoria de escalabilidade/estabilidade/segurança/performance. Escopo: **somente o app do
passageiro** (`C:\JJ-Transportes\moto_passenger`, branch `scalability-review`). Auditoria apenas —
nenhum arquivo de código foi alterado; este documento é o único artefato criado.

---

## Áreas analisadas

- Arquitetura geral (Flutter + `flutter_modular` + Clean Architecture por módulo, `flutter_bloc`)
- Inicialização/splash, recuperação de sessão (token + viagem ativa)
- Login/autenticação, armazenamento seguro de token, refresh token
- Localização (`geolocator`, `permission_handler`) e mapas (`google_maps_flutter`)
- Fluxo completo de viagem: `NewTravelPage` → `WaitingPage` → `TravelTrackingPage`
- Comunicação em tempo real (SignalR — hubs `travel-orders` e `travel-management`) + polling de fallback
- Persistência local (SQLite via `sqflite`) — cache de perfil/viagens/token
- Tratamento de erro e mapeamento de exceções HTTP (Dio)
- Push notifications (OneSignal — configuração vs. implementação real)
- Pipeline de CI/CD (`codemagic.yaml`, `README-PIPELINE.md`) e status real do build iOS
- Segurança: segredos no repositório, logs, autorização client-side
- Android vs iOS: manifests, Info.plist, permissões, background modes
- Especificações `.sdd/specs/` (18 specs) comparadas com o código real, em busca de divergência
- Testes automatizados (`test/`) — cobertura real dos fluxos críticos
- Dependências (`pubspec.yaml`)

---

## Investigação prioritária: "o mapa não carrega"

Quatro causas-candidatas foram identificadas e confirmadas no código real (não são mutuamente
exclusivas — mais de uma pode estar contribuindo). As duas primeiras (PSG-01/PSG-02) são as mais
fortes porque reproduzem exatamente o sintoma relatado (mapa que nunca aparece, sem erro visível)
em condições comuns de uso real (sinal de GPS fraco, primeira leitura de localização demorada).

---

### PSG-01 — `Geolocator.getCurrentPosition()` sem timeout: spinner infinito se o GPS não responder

- **Área**: Localização / Mapa
- **Fluxo**: Nova Viagem → carregamento do mapa (obtenção da localização atual)
- **Arquivo**: `lib/core/location/location_service.dart:34` (chamado por
  `lib/modules/new_travel/presentation/blocs/new_travel_bloc.dart:207-241`, método `_onGetCurrentLocation`)
- **Evidência**:
  ```dart
  // location_service.dart
  final position = await Geolocator.getCurrentPosition();
  return LocationResult(position: position, status: LocationStatus.granted);
  ```
  Nenhum `LocationSettings(timeLimit: ...)` é passado. A mesma ausência de timeout se repete em
  `travel_tracking_page.dart:180` (`_loadMyLocation`).
- **Problema**: `Geolocator.getCurrentPosition()` sem `timeLimit` aguarda indefinidamente até o GPS
  conseguir um fix de alta precisão. Em condições comuns — ambiente fechado/indoor, prédio, primeira
  leitura após o app abrir (GPS "frio"), emulador sem localização simulada, ou simplesmente sinal
  fraco — essa chamada pode nunca resolver. O `NewTravelBloc` fica travado em
  `NewTravelLocationLoading` para sempre; nenhum erro é emitido, nenhum timeout dispara.
- **Como reproduzir**: abrir "Nova Viagem" em local com sinal de GPS fraco/inexistente (dentro de um
  prédio, subsolo, ou emulador Android sem localização configurada) — a tela fica com
  `CircularProgressIndicator` para sempre, sem o mapa aparecer e sem qualquer mensagem de erro.
- **Impacto**: Sintoma idêntico ao relatado ("o mapa não carrega") — tela de carregamento eterna, sem
  feedback, sem opção de tentar novamente. Passageiro (já ansioso/com pressa) fica sem saber se o app
  travou ou está processando.
- **Criticidade**: **Crítico**
- **Recomendação**: Adicionar `LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10-15))`
  ao `Geolocator.getCurrentPosition()`; em caso de timeout, cair para `Geolocator.getLastKnownPosition()`
  como fallback, e só então emitir `NewTravelLocationError` com uma mensagem que ofereça "Tentar
  novamente". Aplicar o mesmo padrão em `travel_tracking_page.dart:_loadMyLocation`.
- **Complexidade**: Baixa (mudança pontual em 1-2 arquivos)
- **Testes necessários**: teste unitário do `LocationService`/`NewTravelBloc` simulando
  `Geolocator.getCurrentPosition()` nunca resolvendo (usar `Completer` não completado) e verificando
  que o estado transiciona para erro após o timeout configurado.

---

### PSG-02 — `NewTravelPage` só renderiza o `GoogleMap` quando a localização já chegou — sem timeout nem retry visível

- **Área**: Mapa / UX
- **Fluxo**: Nova Viagem
- **Arquivo**: `lib/modules/new_travel/presentation/pages/new_travel_page.dart:161-212` (`_buildMap`)
- **Evidência**:
  ```dart
  Widget _buildMap(NewTravelState state) {
    if (state is NewTravelCheckingPending || state is NewTravelLocationLoading) {
      return Container(color: Colors.grey.shade200, child: const Center(child: CircularProgressIndicator()));
    }
    if (_currentLocation != null) {
      return Stack(children: [ GoogleMap(...), ... ]);
    }
    return Container(color: Colors.grey.shade200, child: const Center(child: CircularProgressIndicator()));
  }
  ```
- **Problema**: O widget `GoogleMap` só é construído quando `_currentLocation != null`. Diferente de
  `TravelTrackingPage._buildWithMap` (que usa um centro padrão de São Paulo quando não há coordenada),
  aqui não existe nenhum fallback — se a localização nunca chega (ver PSG-01) ou chega com erro que
  não é tratado corretamente, o usuário nunca vê o mapa, só o spinner cinza. Não há botão "tentar
  novamente" nessa tela de carregamento nem um timeout visível para o usuário.
- **Como reproduzir**: mesmo cenário do PSG-01, ou negar a permissão de localização e depois conceder
  fora do fluxo do diálogo de erro (o diálogo de erro existe — `_showLocationErrorDialog` — mas só é
  acionado se o bloc de fato emitir `NewTravelLocationError`; qualquer caminho que deixe o estado
  "preso" antes disso não aciona esse diálogo).
- **Impacto**: Reforça o PSG-01 — a UI não tem uma defesa própria contra o bloc nunca emitir um
  estado terminal.
- **Criticidade**: **Alto**
- **Recomendação**: Adicionar um timeout na própria UI (ex.: `Future.delayed` de 15s que, se ainda
  em `NewTravelLocationLoading`, mostra um botão "Tentar novamente"/"Continuar sem localização"
  reaproveitando o centro padrão como em `TravelTrackingPage`).
- **Complexidade**: Baixa
- **Testes necessários**: widget test cobrindo o caminho "localização nunca chega" → botão de retry aparece.

---

### PSG-03 — Chaves de API do Google Maps commitadas em texto puro no repositório (Android e Web)

- **Área**: Segurança / Mapa
- **Fluxo**: Build/config — afeta diretamente a disponibilidade do mapa em produção
- **Arquivo**:
  - `android/gradle.properties:6` → `ANDROID_MAPS_API_KEY=AIzaSyDQsRZJUDYRo1Qpp2q3j_bwdnkqQoDYbL8`
  - `web/index.html:36` → `<script src="https://maps.googleapis.com/maps/api/js?key=AIzaSyAJy_4wj5tmbh46y3KbTaLIXwnLF4Q7ENQ"></script>`
- **Evidência**: ambos os arquivos estão versionados no git (não estão no `.gitignore`) e contêm
  chaves reais e funcionais do Google Maps Platform.
- **Problema**: Chaves de API commitadas em repositório privado ainda são um risco — qualquer pessoa
  com acesso ao repo (incluindo histórico de commits antigos, forks, CI logs) tem a chave completa.
  Mais relevante para o bug relatado: se essa chave for restringida (por pacote/SHA-1, por domínio),
  revogada, tiver cota excedida ou for rotacionada por segurança sem atualizar o `gradle.properties`,
  **o mapa para de carregar silenciosamente** — o SDK nativo do Google Maps falha ao carregar tiles e
  não há nenhum tratamento de erro no app Flutter para esse cenário (não existe listener de erro do
  `GoogleMap`/`onMapCreated` que detecte falha de autenticação da chave).
- **Como reproduzir**: inspecionar `git show HEAD:android/gradle.properties` e
  `git show HEAD:web/index.html` — chaves visíveis em texto puro.
- **Impacto**: Risco de segurança (uso indevido/cobrança na conta Google Cloud do projeto) +
  risco operacional (qualquer restrição/rotação futura da chave derruba o mapa em produção sem
  qualquer sinal no app).
- **Criticidade**: **Alto** (segurança) — se comprovado que a chave já teve algum problema de
  cota/restrição, elevar para **Crítico** quanto à causa raiz do bug relatado.
- **Recomendação**: Mover as chaves para variáveis de ambiente do Codemagic (mesmo padrão já usado
  para `IOS_MAPS_API_KEY`), gerar `gradle.properties`/`index.html` a partir delas no pipeline, revogar
  e rotacionar as duas chaves atuais (já expostas), e restringir a nova chave por
  pacote+SHA-1 (Android) / referer (Web/JS). Adicionar um `onMapCreated`/tratamento de erro de tiles
  no app (ex.: monitorar ausência de eventos de câmera/tiles carregados e mostrar mensagem
  "Não foi possível carregar o mapa" após alguns segundos).
- **Complexidade**: Média (mexe em pipeline + requer rotação coordenada de chave em produção)
- **Testes necessários**: verificação manual pós-rotação (build gerado consegue carregar o mapa);
  não é testável via `flutter test` (depende de infraestrutura externa).

---

### PSG-04 — iOS: `IOS_MAPS_API_KEY` nunca é resolvido; não existe build iOS real até hoje

- **Área**: Mapa / Pipeline
- **Fluxo**: Build iOS (afeta qualquer teste feito em iOS)
- **Arquivo**:
  - `ios/Runner/Info.plist:54-55` → `<key>IosMapsApiKey</key><string>$(IOS_MAPS_API_KEY)</string>`
  - `ios/Runner/AppDelegate.swift:12-13` → `GMSServices.provideAPIKey(apiKey)` lê exatamente essa chave
    (o nome customizado da chave está consistente entre Info.plist e AppDelegate — isso está correto)
  - `ios/Flutter/Debug.xcconfig:2` e `Release.xcconfig:2` → `#include "Secrets.xcconfig"` (**não**
    `#include?`, ou seja, é obrigatório) — mas `ios/Flutter/Secrets.xcconfig` está no `.gitignore`
    (`.gitignore:51`) e não existe no repositório.
  - `codemagic.yaml` (arquivo inteiro, 76 linhas): contém **apenas** o workflow `android_staging`.
    Não há workflow `ios_staging`/`ios_release` nesse arquivo.
  - `README-PIPELINE.md:158-195` ("iOS — status"): confirma explicitamente que o pipeline iOS "ainda
    não está no mesmo nível de maturidade", que a conta Apple Developer está em processo de migração,
    e que build assinado real **nunca foi anexado** ao App Store Connect ("hoje aparecem com ícone
    genérico — só resolve com o primeiro build real").
- **Problema**: `$(IOS_MAPS_API_KEY)` só teria valor se viesse de `Secrets.xcconfig` (ausente) ou de
  variável de ambiente injetada por um workflow Codemagic para iOS (inexistente hoje). Ou seja,
  **qualquer build iOS que exista** (local, de um dev que criou seu próprio `Secrets.xcconfig`, ou um
  build manual antigo) provavelmente tem a chave vazia/não resolvida, e `GMSServices.provideAPIKey("")`
  faz o Google Maps SDK no iOS falhar silenciosamente ao carregar tiles.
- **Como reproduzir**: `grep -r IOS_MAPS_API_KEY ios/ codemagic.yaml` — nenhuma definição de valor
  encontrada em nenhum arquivo versionado; confirmar ausência de workflow iOS em `codemagic.yaml`.
- **Impacto**: Se o teste que gerou o relato "mapa não carrega" foi feito em iOS (via TestFlight,
  build ad-hoc, ou simulador com um `Secrets.xcconfig` mal configurado), esta é a causa raiz mais
  provável — o mapa nunca teria a chave correta. Dado que a documentação do próprio time confirma que
  não há build iOS distribuído em produção ainda, isso é mais relevante para simuladores/builds locais
  de desenvolvimento do que para o app já "em produção" mencionado no briefing (que hoje é
  Android-only, via Google Play).
- **Criticidade**: **Alto** (não é a causa mais provável do relato em produção, já que produção é
  Android via Play Store — mas é uma lacuna real e documentada que precisa ser resolvida antes de
  qualquer teste/lançamento em iOS)
- **Recomendação**: Criar os workflows `ios_staging`/`ios_release` no `codemagic.yaml` (gerando
  `Secrets.xcconfig` a partir de variáveis de ambiente do Codemagic, mesmo padrão do Android), e
  bloquear qualquer teste manual em iOS até isso existir — ou, se testes locais são necessários antes
  disso, documentar no README como criar um `Secrets.xcconfig` local válido.
- **Complexidade**: Média
- **Testes necessários**: build iOS de ponta a ponta validando que o mapa carrega (já listado como
  pendente no próprio `README-PIPELINE.md`, seção "iOS — status").

---

### Conclusão sobre o bug do mapa

Não foi possível reproduzir o app rodando (auditoria estática apenas), então a causa raiz não pode
ser **confirmada** com 100% de certeza sem telemetria/logs do dispositivo do usuário que reportou o
bug. Dito isso, a evidência de código aponta fortemente para **PSG-01** (ausência de timeout na
obtenção de localização, causando estado de carregamento infinito) como a causa mais provável para um
app em produção Android com o relato "mapa não carrega" — é o único caminho que reproduz exatamente
"spinner sem fim, sem erro" a partir de uma condição comum (GPS lento/indisponível), sem depender de
nenhuma falha externa (chave, rede, pipeline). PSG-02 é a mesma causa vista pelo lado da UI (falta de
timeout/retry). PSG-03 e PSG-04 são riscos reais e confirmados mas dependem de uma condição externa
(rotação/restrição de chave, ou uso em iOS) que não pôde ser confirmada como tendo ocorrido de fato.
Recomenda-se corrigir PSG-01/02 primeiro (mudança pequena, de baixo risco, com alto valor), e tratar
PSG-03/04 como itens de segurança/pipeline independentemente de serem ou não a causa deste relato
específico.

---

## Outros achados

### PSG-05 — Push notifications (OneSignal) configuradas mas não integradas de fato — SDK ausente

- **Área**: Notificações / Confiabilidade
- **Fluxo**: Motorista aceita viagem com app do passageiro fechado/em background
- **Arquivo**:
  - `pubspec.yaml` — **não há** dependência `onesignal_flutter` (nem em `pubspec.lock`)
  - `lib/core/config/app_config.dart:5,8,12` — `getOneSignalAppId()` lê `ONE_SIGNAL_ID` do `.env` mas
    o valor retornado **não é consumido em nenhum outro lugar do código** (único call site é a própria
    definição — confirmado por busca em todo `lib/`)
  - `lib/modules/auth/data/datasources/auth_datasource.dart:63-66` e `i_auth_datasource.dart:30-32` —
    `registerDeviceToken(playerId, platform)` existe (chama um endpoint de backend) mas **nunca é
    chamado** em nenhum ponto do app (login, splash, etc.)
  - `lib/core/auth/sign_out_service.dart:20-28` — `signOut()` só limpa storage local e local DB;
    não desregistra o device do OneSignal nem chama nenhum endpoint de backend para isso — apesar do
    comentário em `test/core/auth/sign_out_service_test.dart:76` dizer *"Ordem: OneSignal → backend
    sign-out (neutraliza device) → limpeza local"*, o que **não corresponde** à implementação real.
  - `ios/Podfile` e `pubspec.lock`: nenhuma referência a OneSignal.
- **Problema**: Toda a infraestrutura de configuração para push (App ID, variável de ambiente no
  Codemagic, endpoint de backend para registrar device, comentários de código referenciando o fluxo)
  existe, mas o SDK do OneSignal nunca foi de fato adicionado como dependência nem inicializado
  (`OneSignal.initialize(...)`) em nenhum lugar. Isso indica uma feature parcialmente implementada ou
  removida sem limpar os resquícios.
- **Como reproduzir**: `grep -ri onesignal pubspec.yaml pubspec.lock ios/Podfile` → nenhum resultado;
  `grep -rn "getOneSignalAppId\|registerDeviceToken" lib/` → apenas definições, nenhuma chamada real.
- **Impacto**: **Passageiro não recebe nenhuma notificação push** quando o motorista aceita a corrida,
  quando a viagem inicia/termina/é cancelada, se o app estiver fechado ou em background profundo
  (fora do alcance de SignalR/polling, que só funcionam com o app em execução). A única forma de o
  passageiro descobrir que a corrida foi aceita é reabrir o app manualmente — o que combinado com o
  cenário "fecha o app, motorista aceita, reabre o app" (que o próprio código trata bem, ver PSG-12)
  significa que o usuário depende inteiramente de lembrar de checar o app.
- **Criticidade**: **Crítico**
- **Recomendação**: Decidir entre (a) implementar de fato o OneSignal (adicionar dependência,
  `OneSignal.initialize()` no `main.dart`, chamar `registerDeviceToken` após login, desregistrar no
  `signOut()`) ou (b) remover os resquícios (env var, endpoint morto, comentário de teste incorreto)
  se push não for prioridade agora — mas não deixar a aparência de que push funciona quando não
  funciona.
- **Complexidade**: Média (integração de SDK nativo em Android+iOS, requer chave de servidor OneSignal
  configurada no painel + testes em dispositivo real)
- **Testes necessários**: teste manual ponta a ponta (app fechado → motorista aceita → notificação
  chega e abre a tela correta via `NotificationHandler`, que já existe e está pronto para receber os
  dados — só falta o SDK entregar o payload).

---

### PSG-06 — Renovação de token só ocorre no cold start; sem interceptor para 401 durante sessão ativa

- **Área**: Autenticação / Sessão
- **Fluxo**: Sessão longa — esperando motorista, ou viagem longa, com token de acesso expirando no meio
- **Arquivo**: `lib/core/http/dio_client.dart:1-51` (interceptor único é `AuthInterceptor`, que só
  **anexa** o token, não trata resposta 401); `lib/screens/splash_screen.dart:80-108`
  (`_tryRefreshToken`, único lugar onde o refresh token é de fato usado)
- **Evidência**:
  ```dart
  // dio_client.dart — único interceptor de request, nenhum interceptor de erro/response
  class AuthInterceptor extends Interceptor {
    Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
      final token = await storage.getToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    }
  }
  ```
  `getRefreshToken()` (`auth_storage.dart:31`) só é chamado a partir de `splash_screen.dart:42`.
- **Problema**: O refresh token é usado corretamente **ao abrir o app** (splash), mas não existe
  nenhum `onError`/interceptor no Dio que capture uma resposta 401 durante o uso normal do app
  (esperando motorista, em viagem, etc.), tente renovar o token com o refresh token já disponível, e
  repita a requisição original. Qualquer chamada de API feita após o access token expirar durante uma
  sessão longa vai falhar com 401 cru (mapeado para `UnauthorizedException('Credenciais inválidas')`
  em vários datasources), sem tentativa de recuperação silenciosa.
- **Como reproduzir**: manter o app aberto (sem fechar) por tempo maior que o TTL do access token
  (não visível no client, depende do backend) durante uma espera longa por motorista — qualquer
  chamada subsequente (poll de status, cancelamento, etc.) recebe 401 e mostra "Credenciais
  inválidas", uma mensagem enganosa (parece senha errada, não sessão expirada).
- **Impacto**: Passageiro em viagem longa pode subitamente não conseguir cancelar/ver atualização,
  com uma mensagem de erro que não indica o problema real nem a solução (relogar).
- **Criticidade**: **Alto**
- **Recomendação**: Adicionar um `QueuedInterceptor`/`onError` ao `DioClient` que, ao receber 401,
  tenta renovar via `IAuthDatasource.refreshToken` (reaproveitando a lógica já existente em
  `_tryRefreshToken`), repete a requisição original em caso de sucesso, e força logout + navegação
  para `/login` com mensagem clara ("Sua sessão expirou, faça login novamente") em caso de falha.
- **Complexidade**: Média
- **Testes necessários**: teste do `DioClient`/interceptor simulando 401 seguido de refresh
  bem-sucedido (request repetida com novo token) e refresh falho (logout forçado).

---

### PSG-07 — Cobertura de testes zero nos fluxos críticos de mapa/corrida

- **Área**: Testes
- **Fluxo**: Todo o fluxo de solicitação/acompanhamento de corrida
- **Arquivo**: diretório `test/` (18 arquivos, todos em `test/core/*` e `test/modules/auth/*` +
  `test/screens/splash_screen_test.dart`); confirmado também pelas próprias specs versionadas:
  - `.sdd/specs/map-recenter-button/requirements.md:23-24`: *"Sem testes existentes para
    `new_travel_page.dart`/`travel_tracking_page.dart`"*
  - `.sdd/specs/map-single-tap-and-waiting-lockout/requirements.md:32-33`: *"Sem testes existentes
    para `new_travel_page.dart`/`waiting_page.dart`"*
  - `.sdd/specs/home-fab-block-active-travel/requirements.md:34`: *"Sem testes existentes para esta
    página/mixin"*
  - `.sdd/specs/tracking-back-to-home/requirements.md:34`: *"Sem testes existentes para
    `travel_tracking_page.dart`"*
- **Problema**: Não existe nenhum teste (unitário, widget ou de bloc) para `NewTravelBloc`,
  `TravelTrackingBloc`, `PassengerHomeBloc`, `NewTravelPage`, `TravelTrackingPage`, `WaitingPage` —
  ou seja, **nenhum dos fluxos críticos auditados neste relatório tem qualquer rede de segurança
  automatizada**. Toda a lógica de polling/backoff, deduplicação de eventos SignalR, guarda contra
  regressão de estado (`_updateStateFromTravel`), recuperação de sessão com corrida ativa, etc. —
  tudo isso, por mais bem escrito que esteja hoje, pode quebrar silenciosamente em qualquer alteração
  futura sem que o CI (`flutter test` no `codemagic.yaml`) perceba.
- **Como reproduzir**: `find test -type f` lista somente arquivos de auth/utils/splash; nenhum arquivo
  cobre `lib/modules/new_travel/*` ou `lib/modules/passenger_home/*`.
- **Impacto**: O pipeline de CI (`codemagic.yaml`, passo "Run tests") passa "verde" mesmo que o fluxo
  inteiro de solicitar/acompanhar corrida esteja quebrado — o teste automatizado simplesmente não
  olha para essa área.
- **Criticidade**: **Alto**
- **Recomendação**: Priorizar testes de bloc (`bloc_test`, já é dev dependency) para
  `NewTravelBloc._onGetCurrentLocation` (cobrindo PSG-01), `TravelTrackingBloc` (polling/backoff/
  deduplicação, que já tem lógica complexa o suficiente para merecer testes), e
  `PassengerHomeBloc._onLoad` (cache-first + fallback). Testes de widget para os gates de
  renderização do mapa (PSG-02).
- **Complexidade**: Alta (volume grande de casos a cobrir, mocks de `SignalRService`/`Geolocator`/
  `Dio` necessários)
- **Testes necessários**: ver recomendação acima — este item *é* sobre testes necessários.

---

### PSG-08 — Nenhum `WidgetsBindingObserver`/`AppLifecycleState` em todo o app

- **Área**: Performance / Bateria / Ciclo de vida
- **Fluxo**: App em background durante busca por motorista ou viagem em andamento
- **Arquivo**: busca em todo `lib/` por `WidgetsBindingObserver`/`AppLifecycleState`/
  `didChangeAppLifecycleState` — **zero ocorrências** em todo o projeto.
- **Problema**: `TravelTrackingBloc` mantém um `Timer.periodic` de polling (10s, com backoff para 30s
  após falhas — `travel_tracking_bloc.dart:57-63`) que roda continuamente enquanto o bloc existir,
  sem qualquer pausa quando o app vai para background. Da mesma forma, as conexões SignalR
  (`SignalRService`) não são pausadas/reconectadas de forma proativa ao voltar do background — o app
  depende inteiramente do comportamento default do `signalr_netcore` e do SO (que pode suspender o
  isolate Dart de qualquer forma, tornando o comportamento não determinístico). Não há também nenhuma
  lógica de "ao voltar para o foreground, force um refresh imediato" — a única forma de refresh ao
  voltar de outra tela é via `RouteObserver`/`didPopNext` (`home-fab-block-active-travel` spec), que
  cobre navegação interna, não retorno do background do SO.
  Também não sendo pausado enquanto o app está fechado, e SignalR sendo forçado a reconectar do zero
  em cada volta ao app (por não haver estado de app-lifecycle nenhum), o app depende puramente da
  auto-reconexão do `signalr_netcore` (`.withAutomaticReconnect()`), sem garantia de que eventos
  perdidos durante o tempo desconectado sejam re-sincronizados alem do polling de fallback do
  `TravelTrackingBloc` (que só existe em `TravelTrackingPage`, não em `WaitingPage` — lá, se o
  SignalR cair enquanto o app está em background esperando aceite, não há nenhum polling de reserva,
  só o comentário `// Non-critical; polling in TravelTrackingPage will be the fallback`, que é falso
  para esta tela especificamente, já que `WaitingPage` não tem polling próprio).
- **Como reproduzir**: colocar o app em background durante `WaitingPage` (aguardando motorista) por
  tempo suficiente para o SO suspender a conexão SignalR sem que o app perceba; ao voltar, não há
  garantia de reconciliação de estado além do que o SignalR auto-reconectar entregar.
- **Impacto**: Consumo desnecessário de bateria/rede quando o polling continua rodando em background
  sem necessidade; risco de estado desatualizado ao retornar do background em `WaitingPage`
  especificamente (sem fallback de polling), incluindo perder o evento `OrderAccepted` se ele chegar
  exatamente durante uma reconexão SignalR silenciosa.
- **Criticidade**: **Médio**
- **Recomendação**: Adicionar um `WidgetsBindingObserver` nas páginas com Timer/SignalR ativo
  (`WaitingPage`, `TravelTrackingPage`) para (a) pausar o polling em background profundo se aplicável,
  e (b) ao retornar a `resumed`, forçar imediatamente uma consulta do estado atual via REST (mesmo
  padrão de `LoadTravel`/`getLatestOrder`) independente do estado da conexão SignalR, cobrindo o
  gap de `WaitingPage` não ter polling de fallback.
- **Complexidade**: Média
- **Testes necessários**: teste de widget simulando `AppLifecycleState.paused` →
  `AppLifecycleState.resumed` e verificando que um refresh de estado é disparado.

---

### PSG-09 — Guarda fraca contra duplo toque em "Solicitar Viagem" (defesa em profundidade ausente)

- **Área**: UX / Confiabilidade
- **Fluxo**: Confirmação de pedido de corrida
- **Arquivo**: `lib/modules/new_travel/presentation/blocs/new_travel_bloc.dart:154-193` (`_onConfirm`)
- **Evidência**: `_onConfirm` não verifica `state is NewTravelCreating` no início antes de prosseguir;
  a única proteção contra clique duplo é em `new_travel_page.dart:653` (`onPressed: isCreating ? null
  : ...`), que depende do rebuild do `BlocBuilder` já ter acontecido.
- **Problema**: A UI desabilita o botão somente depois que o estado `NewTravelCreating` já foi emitido
  e a árvore de widgets foi reconstruída. Não há guarda síncrona no próprio bloc
  (`if (state is NewTravelCreating) return;` logo no início de `_onConfirm`). `BACKEND_CHANGES_TODO.md`
  linha 92 registra isso explicitamente como pendência: *"garantir que o app não solicita a corrida
  mais de uma vez por toque do usuário"* — item sem checkbox marcado.
- **Como reproduzir**: não confirmado como reproduzível de forma confiável em teste manual (a janela
  de tempo é muito pequena para um toque humano real); é uma lacuna estrutural, não um bug observado.
- **Impacto**: Risco de pedido duplicado de corrida em cenários de baixo desempenho de dispositivo
  (frame drop atrasando o rebuild) ou de testes automatizados/acessibilidade que disparam eventos
  sintéticos mais rápido que um toque humano. Mitigado parcialmente pelo rate limit de backend (10
  pedidos/5min, `BACKEND_CHANGES_TODO.md:79-92`), mas isso não impede um duplo pedido isolado.
- **Criticidade**: **Médio**
- **Recomendação**: Adicionar guarda explícita no início de `_onConfirm`:
  `if (state is NewTravelCreating) return;` — mudança de uma linha, sem efeitos colaterais.
- **Complexidade**: Baixa
- **Testes necessários**: teste de bloc disparando dois `ConfirmTravel` em sequência imediata e
  verificando que só uma chamada ao repositório ocorre.

---

### PSG-10 — Mensagem de erro técnica pode vazar ao usuário quando a criação de viagem falha sem resposta HTTP

- **Área**: UX / Tratamento de erro
- **Fluxo**: Solicitar viagem, com perda de conexão durante a requisição
- **Arquivo**: `lib/modules/new_travel/data/datasources/new_travel_datasource.dart:44-58`
- **Evidência**:
  ```dart
  if (e.response?.statusCode == 429) { throw RateLimitedException(...); }
  if (e.response?.statusCode == 400) { throw ValidationException(...); }
  if ((e.response?.statusCode ?? 0) >= 500) { throw const ServerException(); }
  throw Exception(e.message ?? 'Erro ao criar viagem'); // <- fallback genérico
  ```
  Consumido em `new_travel_bloc.dart:190-191`: `catch (e) { emit(NewTravelFailure(message:
  e.toString())); }`, exibido diretamente em um `SnackBar` (`new_travel_page.dart:87-92`).
  Todas as exceções customizadas do projeto (`ValidationException`, `RateLimitedException`,
  `ServerException`, etc., em `lib/core/errors/exceptions.dart`) têm `toString()` limpo (só a
  mensagem em português); mas o `Exception(e.message ?? ...)` do fallback é um `Exception` nativo do
  Dart, cujo `toString()` antepõe `"Exception: "`, e `e.message` de uma `DioException` **sem
  resposta HTTP** (timeout de conexão, falha de DNS, sem internet) é geralmente uma string técnica em
  inglês vinda do próprio Dio (ex.: `"The connection errored: ..."`).
- **Problema**: O único cenário que cai nesse fallback genérico é justamente "sem resposta HTTP" —
  ou seja, exatamente o cenário de perda de internet, que é um dos cenários adversos centrais do
  escopo desta auditoria. Nesse caso específico, o passageiro pode ver uma mensagem técnica em inglês
  em vez de algo como "Sem conexão com a internet. Verifique sua rede e tente novamente."
- **Como reproduzir**: desligar a internet do dispositivo/emulador no momento de tocar em "Solicitar
  Viagem" e observar o texto do `SnackBar` de erro.
- **Impacto**: UX ruim especificamente no cenário de perda de conectividade, que é comum e esperado.
  Compare com `PassengerHomeDatasource._mapException` (linha 63-72), que já trata esse caso
  corretamente com `NetworkException('Erro de conexão')` — o padrão existe no projeto, só não foi
  replicado em `NewTravelDatasource`.
- **Criticidade**: **Médio**
- **Recomendação**: No fallback de `createOrder`/`createPriorityOrder`, checar `e.type` (
  `DioExceptionType.connectionTimeout`, `.receiveTimeout`, `.connectionError`) e lançar
  `NetworkException` (já existe, já é usada em outro datasource do mesmo projeto) em vez do
  `Exception` genérico.
- **Complexidade**: Baixa
- **Testes necessários**: teste do datasource simulando `DioException(type: connectionError)` e
  verificando que `NetworkException` (mensagem em português) é lançada.

---

### PSG-11 — `SignOutService` não corresponde ao comportamento documentado em comentário de teste

- **Área**: Consistência / Segurança
- **Fluxo**: Logout
- **Arquivo**: `lib/core/auth/sign_out_service.dart:20-28` vs.
  `test/core/auth/sign_out_service_test.dart:76`
- **Problema**: o comentário do teste (*"Ordem: OneSignal → backend sign-out (neutraliza device) →
  limpeza local"*) descreve um comportamento que não existe na implementação atual (que só limpa
  storage/DB local e navega para `/login` — sem chamar backend, sem OneSignal). Ligado a PSG-05.
- **Impacto**: Documentação/comentário enganoso para quem for manter o código; indica possivelmente
  uma refatoração incompleta (feature removida sem atualizar comentários/testes).
- **Criticidade**: **Baixo**
- **Recomendação**: Atualizar o comentário para refletir a realidade, ou implementar de fato o
  desregistro de device (ligado à decisão tomada em PSG-05).
- **Complexidade**: Baixa
- **Testes necessários**: nenhum adicional além do já coberto por PSG-05.

---

### PSG-12 — [Validado, não é bug] Recuperação de sessão com corrida ativa ao reabrir o app funciona corretamente

- **Área**: Persistência / Recuperação de sessão
- **Fluxo**: Passageiro solicita corrida → fecha o app → motorista aceita → passageiro reabre o app
- **Arquivo**: `lib/screens/splash_screen.dart:110-133` (`_checkActiveTravel`) +
  `lib/modules/passenger_home/presentation/blocs/passenger_home_bloc.dart:34-88` (`_onLoad`) +
  `lib/modules/passenger_home/data/repositories/passenger_home_repository.dart:22-46`
  (`getActiveTravel`, com fallback para endpoint antigo em caso de erro) +
  `lib/core/local_db/repositories/travel_local_repository.dart`
- **Evidência**: `SplashScreen._checkActiveTravel` consulta o cache local (`TravelLocalRepository`),
  e se houver uma viagem `Accepted`/`InProgress`, **valida contra o backend** (`GET
  /api/travels/{id}`) antes de navegar direto para `TravelTrackingPage` — evitando navegar para uma
  viagem que já não existe mais no servidor. Se o status for `Pending`, não navega direto, mas a Home
  (`PassengerHomeBloc._onLoad`) também busca a viagem ativa via `/api/travels/active` (com fallback
  para `/api/travels/passenger?status=Accepted,InProgress` em caso de erro) independentemente do
  status, populando o `CurrentTravelCard`, que ao ser tocado navega para `TravelTrackingPage` — que
  por sua vez já trata corretamente o estado `Pending` (`_buildPendingState`).
- **Conclusão**: o cenário-chave pedido explicitamente nesta auditoria **é tratado corretamente** no
  código atual — tanto pelo caminho direto (splash → tracking, para Accepted/InProgress) quanto pelo
  caminho indireto (splash → home → card de viagem ativa → tracking, para Pending ou como fallback
  geral). Cache local é usado apenas para exibição otimista; o servidor é sempre a fonte de verdade
  final, com tratamento de erro (`catch (_) { travelRepo.clearTravels(); }`) para o caso da viagem já
  não existir mais.
- **Criticidade**: **Informativo** (nenhuma ação necessária)

---

### PSG-13 — `.env` sem exemplo documentado para onboarding

- **Área**: DX / Robustez de inicialização
- **Fluxo**: Primeiro build local de um novo desenvolvedor/QA
- **Arquivo**: `lib/main.dart:15-16` (`await dotenv.load(); await AppConfig.loadEnv();`) +
  `lib/core/config/app_config.dart:11-12` (`dotenv.get('API_BASE_URL')` — lança se a chave não
  existir); `.gitignore:48` (`.env` ignorado); nenhum `.env.example` no repositório.
- **Problema**: `main()` não tem `try/catch` ao redor de `dotenv.load()`/`AppConfig.loadEnv()`. Um
  clone novo do repositório sem um `.env` local (o `.env` existente neste checkout é de
  desenvolvimento local, não versionado) faz o app falhar/travar antes mesmo do `runApp()`, com uma
  exceção não tratada — tela branca/crash, sem nenhuma mensagem amigável. Não há `.env.example` no
  repo nem instrução no `README.md` sobre como criar o arquivo localmente (o `codemagic.yaml` gera o
  `.env` automaticamente só em CI).
- **Impacto**: Não afeta produção (CI sempre gera o `.env`), mas gera fricção/confusão para
  desenvolvedores novos e pode ser confundido com um bug mais sério ("o app nem abre").
- **Criticidade**: **Baixo**
- **Recomendação**: Adicionar `.env.example` versionado com placeholders, e/ou tratar a ausência das
  chaves com uma mensagem de erro clara em vez de deixar a exceção do `dotenv` propagar crua.
- **Complexidade**: Baixa
- **Testes necessários**: nenhum crítico; validação manual.

---

### PSG-14 — Testes reativados recentemente: sem confirmação documentada do primeiro build real pós-reativação

- **Área**: CI/CD
- **Fluxo**: Pipeline `android_staging`
- **Arquivo**: `codemagic.yaml:41-42` (passo "Run tests" → `flutter test`); histórico de commits
  (`git log --all --oneline -i --grep=test`) mostra: `ca7f263 Fix 4 failing tests in android_staging
  (login_page_test.dart)`, `a14d673 chore: re-enable test gate on android_staging`, `ffed8de chore:
  re-enable test gate on android_release`, `5942dfe chore: disable test gate for this production
  rollout, enable separately later`, `422aaa4 Resolve merge conflict: keep tests enabled on
  android_release`.
- **Problema**: O histórico confirma que o gate de testes foi desativado e reativado mais de uma vez
  (inclusive um commit que desativa deliberadamente "for this production rollout"), e que havia
  testes quebrados corrigidos (`ca7f263`). Não há, dentro do repositório (nem em `README-PIPELINE.md`,
  que é o documento vivo do time para esse assunto), nenhum registro do resultado do primeiro build
  completo após a reativação definitiva — não é possível, sem acesso ao painel do Codemagic, confirmar
  se o build mais recente de `android_staging` passou em todos os testes com o gate ativo.
- **Impacto**: Risco de o gate de testes estar reativado no `codemagic.yaml` mas o time não ter
  visibilidade se o build mais recente realmente passou limpo — especialmente relevante dado que
  PSG-07 mostra que os testes existentes não cobrem os fluxos mais críticos do app mesmo quando
  passam.
- **Criticidade**: **Baixo** (risco de processo, não de código)
- **Recomendação**: Confirmar no painel do Codemagic (fora do escopo desta auditoria estática) o
  resultado do build mais recente de `android_staging`/`android_release`, e documentar isso em
  `README-PIPELINE.md` como parte do "documento vivo" já mencionado nele.
- **Complexidade**: N/A (verificação, não código)
- **Testes necessários**: N/A

---

## Resumo por criticidade

| Criticidade | IDs |
|---|---|
| Crítico | PSG-01, PSG-05 |
| Alto | PSG-02, PSG-03, PSG-04, PSG-06, PSG-07 |
| Médio | PSG-08, PSG-09, PSG-10 |
| Baixo | PSG-11, PSG-13, PSG-14 |
| Informativo (validado, não é bug) | PSG-12 |

---

## Limitações

- Auditoria **estática** — nenhum build/execução real do app foi feita (Flutter/Android SDK/Xcode não
  disponíveis neste ambiente de auditoria); nenhum dos achados foi confirmado rodando o app em
  dispositivo/emulador real. Isso é especialmente relevante para PSG-01/02/03/04 (bug do mapa): a
  causa raiz mais provável foi identificada por análise de código, não reproduzida ao vivo.
- Não foi possível acessar o painel do Codemagic (histórico real de builds, logs, status de testes
  passados) — toda a análise de CI se baseou no `codemagic.yaml` versionado e no `README-PIPELINE.md`.
  O item PSG-14 registra essa lacuna explicitamente.
- Não foi feita varredura de CVE/vulnerabilidades conhecidas por pacote (sem acesso à internet neste
  ambiente); as versões em `pubspec.yaml` foram apenas inspecionadas quanto à presença/coerência, não
  comparadas contra advisories públicos.
- O escopo desta auditoria é exclusivamente o app do passageiro (`moto_passenger`); qualquer
  comportamento do app do motorista (`moto_driver`) ou do backend só foi considerado quando
  documentado nos artefatos deste repositório (`BACKEND_CHANGES_TODO.md`, `.sdd/specs/`).
- As chaves de API expostas (PSG-03) foram identificadas e citadas neste relatório para fins de
  evidência; nenhuma ação de rotação/revogação foi tomada (auditoria não faz alterações).
- As 18 specs em `.sdd/specs/` foram lidas (`design.md`/`requirements.md`) e comparadas ao código
  real para as áreas de mapa/corrida; todas as verificadas (`map-recenter-button`,
  `map-single-tap-and-waiting-lockout`, `driver-contacted-screen`, `home-fab-block-active-travel`,
  `tracking-back-to-home`) estavam **consistentes** com a implementação atual — nenhuma divergência
  encontrada nessas specs além das lacunas de teste que elas mesmas já documentam (refletidas em
  PSG-07).
