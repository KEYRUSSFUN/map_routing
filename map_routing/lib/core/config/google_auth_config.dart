/// Web Client ID из Google Cloud Console (тип «Web application»).
/// Нужен для получения id_token на Android/iOS.
/// Замените на свой client id перед использованием Google Sign-In.
const String googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue:
      '393960878436-jdf4trd7ivbkjni7e3eqv9ibpei01700.apps.googleusercontent.com',
);
