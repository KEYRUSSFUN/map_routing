from extensions import db
from models import MessageReaction, User

ALLOWED_REACTION_EMOJIS = frozenset({'👍', '🔥', '❤️', '👏', '😂', '😮'})


def _member_name(user):
    if user and user.user_info:
        return user.user_info.name
    if user:
        return f'User {user.id_User}'
    return 'User'


def reactions_for_message_id(message_id):
    reactions = MessageReaction.query.filter_by(message_id=message_id).all()
    result = []
    for reaction in reactions:
        user = reaction.user or User.query.get(reaction.user_id)
        result.append({
            'user_id': reaction.user_id,
            'user_name': _member_name(user),
            'emoji': reaction.emoji,
        })
    return result


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
