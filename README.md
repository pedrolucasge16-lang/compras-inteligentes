# Compras Inteligentes

Aplicativo Flutter em português brasileiro para lista de compras, orçamento, histórico local e comparador de quantidades/preços.

## Requisitos
- Flutter estável instalado (recomendado Flutter 3.24 ou superior).
- Para compilar localmente: Android SDK/Android Studio. Em celular, prefira GitHub Actions.
- O OCR usa Google ML Kit no dispositivo e requer Android compatível.

## Rodar e verificar
```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Gerar APK
```bash
flutter build apk --release
```
O arquivo será `build/app/outputs/flutter-apk/app-release.apk`.

## APK pelo GitHub Actions
1. Envie todos os arquivos deste projeto para a raiz do repositório GitHub.
2. Abra a aba **Actions**.
3. Se solicitado, habilite workflows.
4. Execute o workflow **Build APK** (ou faça um push).
5. Abra a execução concluída e baixe o artefato `compras-inteligentes-apk`.
6. Extraia o ZIP baixado no celular e instale o APK. Talvez seja necessário permitir instalação pelo navegador/gerenciador de arquivos.

## Observações
- Lista, orçamento, histórico e configurações são armazenados localmente no SQLite do aparelho.
- A finalização da compra grava cabeçalho e itens numa transação antes de limpar a lista ativa.
- O OCR apenas sugere texto e preço; revise sempre antes de salvar. A extração de preço é heurística e pode errar.
- O histórico é mantido no aparelho; não há sincronização na nuvem nem conta/login.
- Testes automatizados cobrem cálculos principais. A compilação Android precisa ser confirmada pelo workflow no GitHub Actions.
