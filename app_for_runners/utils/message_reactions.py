from sqlalchemy.orm import joinedload

from extensions import db
from models import MessageReaction, User

ALLOWED_REACTION_EMOJIS = frozenset({'👍', '🔥', '❤️', '👏', '😂', '😮'})


def _member_name(user):
    if user and user.user_info:
        return user.user_info.name
    if user:
        return f'User {user.id_User}'
    return 'User'


def _serialize_reaction_row(reaction):
    user = reaction.user
    return {
        'user_id': reaction.user_id,
        'user_name': _member_name(user),
        'emoji': reaction.emoji,
    }


def reactions_for_message_id(message_id):
    reactions = (
        MessageReaction.query.filter_by(message_id=message_id)
        .options(joinedload(MessageReaction.user).joinedload(User.user_info))
        .all()
    )
    return [_serialize_reaction_row(reaction) for reaction in reactions]


def reactions_map_for_message_ids(message_ids):
    if not message_ids:
        return {}

    reactions = (
        MessageReaction.query.filter(MessageReaction.message_id.in_(message_ids))
        .options(joinedload(MessageReaction.user).joinedload(User.user_info))
        .all()
    )
    by_message = {}
    for reaction in reactions:
        by_message.setdefault(reaction.message_id, []).append(
            _serialize_reaction_row(reaction),
        )
    return by_message


def serialize_message_reactions(message):
    return reactions_for_message_id(message.id)


def toggle_message_reaction(message_id, user_id, emoji):
    emoji = (emoji or '').strip()
    if emoji not in ALLOWED_REACTION_EMOJIS:
        raise ValueError('Invalid reaction emoji')

    existing = MessageReaction.query.filter_by(
        message_id=message_id,
        user_id=user_id,
    ).first()

    if existing:
        if existing.emoji == emoji:
            db.session.delete(existing)
        else:
            existing.emoji = emoji
    else:
        db.session.add(MessageReaction(
            message_id=message_id,
            user_id=user_id,
            emoji=emoji,
        ))

    db.session.commit()
    return reactions_for_message_id(message_id)
