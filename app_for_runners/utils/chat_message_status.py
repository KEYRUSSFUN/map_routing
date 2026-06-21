from datetime import datetime, timezone

from extensions import db
from models import UserGroupChatAssociation


def as_utc(value):
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def relevant_other_associations(chat_id, sender_id, message_timestamp):
    message_ts = as_utc(message_timestamp)
    associations = UserGroupChatAssociation.query.filter(
        UserGroupChatAssociation.chat_id == chat_id,
        UserGroupChatAssociation.user_id != sender_id,
    ).all()

    relevant = []
    for association in associations:
        joined_at = as_utc(association.joined_at)
        if joined_at is not None and message_ts is not None and joined_at > message_ts:
            continue
        relevant.append(association)
    return relevant


def member_effective_received_at(association):
    read_at = as_utc(association.last_read_at)
    received_at = as_utc(association.last_received_at)
    candidates = [value for value in (read_at, received_at) if value is not None]
    if not candidates:
        return None
    return max(candidates)


def outgoing_message_status(message, chat_id, sender_id):
    if message.id is None:
        return 'sending'

    message_ts = as_utc(message.timestamp)
    others = relevant_other_associations(chat_id, sender_id, message_ts)
    if not others:
        return 'read'

    all_read = True
    all_delivered = True
    for association in others:
        read_at = as_utc(association.last_read_at)
        if read_at is None or (message_ts is not None and read_at < message_ts):
            all_read = False

        effective_received = member_effective_received_at(association)
        if effective_received is None or (
            message_ts is not None and effective_received < message_ts
        ):
            all_delivered = False

    if all_read:
        return 'read'
    if all_delivered:
        return 'delivered'
    return 'sent'


def touch_member_received(association, up_to_timestamp):
    target = as_utc(up_to_timestamp) or datetime.now(timezone.utc)
    current = as_utc(association.last_received_at)
    if current is None or target > current:
        association.last_received_at = target


def touch_received_from_messages(association, messages):
    if not messages:
        return None
    latest = max(as_utc(message.timestamp) for message in messages)
    touch_member_received(association, latest)
    return latest


def member_states_for_chat(chat_id):
    rows = UserGroupChatAssociation.query.filter_by(chat_id=chat_id).all()
    return [
        {
            'userId': row.user_id,
            'lastReadAt': row.last_read_at,
            'lastReceivedAt': row.last_received_at,
        }
        for row in rows
    ]
