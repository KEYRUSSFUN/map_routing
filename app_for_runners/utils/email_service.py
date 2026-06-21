import logging
import smtplib
import ssl
from email.headerregistry import Address
from email.message import EmailMessage

from flask import current_app

logger = logging.getLogger(__name__)


class EmailDeliveryError(Exception):
    """Не удалось отправить письмо через SMTP."""


def is_smtp_configured(app=None):
    app = app or current_app
    return bool(app.config.get('SMTP_USER') and app.config.get('SMTP_PASSWORD'))


def send_password_reset_email(*, to_email: str, code: str, ttl_minutes: int) -> None:
    app = current_app
    if not is_smtp_configured(app):
        logger.warning(
            'SMTP не настроен — письмо с кодом восстановления не отправлено (%s)',
            to_email,
        )
        raise EmailDeliveryError('SMTP не настроен')

    subject = 'StrideTrack — код для восстановления пароля'
    body = (
        'Здравствуйте!\n\n'
        f'Ваш код для восстановления пароля: {code}\n\n'
        f'Код действует {ttl_minutes} мин.\n'
        'Если вы не запрашивали сброс пароля, просто проигнорируйте это письмо.\n\n'
        '— StrideTrack'
    )

    username = app.config['SMTP_USER'].strip()
    from_name = (app.config.get('MAIL_FROM_NAME') or 'StrideTrack').strip()
    # Яндекс требует, чтобы отправитель совпадал с учётной записью SMTP.
    from_email = (app.config.get('MAIL_FROM') or username).strip()
    if from_email.lower() != username.lower():
        logger.warning(
            'MAIL_FROM (%s) не совпадает с SMTP_USER — для Яндекса используем SMTP_USER',
            from_email,
        )
        from_email = username

    message = EmailMessage()
    message['Subject'] = subject
    message['From'] = Address(display_name=from_name, addr_spec=from_email)
    message['To'] = to_email
    message.set_content(body, charset='utf-8')

    host = app.config.get('SMTP_HOST', 'smtp.yandex.ru')
    port = int(app.config.get('SMTP_PORT', 465))
    password = app.config['SMTP_PASSWORD']
    use_starttls = bool(app.config.get('SMTP_USE_STARTTLS', port == 587))

    try:
        if use_starttls:
            with smtplib.SMTP(host, port, timeout=30) as smtp:
                smtp.ehlo()
                smtp.starttls(context=ssl.create_default_context())
                smtp.ehlo()
                smtp.login(username, password)
                smtp.send_message(message)
        else:
            context = ssl.create_default_context()
            with smtplib.SMTP_SSL(host, port, context=context, timeout=30) as smtp:
                smtp.login(username, password)
                smtp.send_message(message)
    except Exception as exc:
        logger.exception('Ошибка SMTP при отправке на %s', to_email)
        raise EmailDeliveryError('Ошибка SMTP') from exc

    logger.info('Письмо восстановления пароля отправлено на %s', to_email)

