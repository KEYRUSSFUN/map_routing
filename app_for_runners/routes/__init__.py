def register_blueprints(app):
    from .auth import auth_bp
    from .friends import friends_bp
    from .chat import chat_bp
    from .profile import profile_bp
    from .statistics import statistics_bp
    from .routes_bp import routes_bp
    from .achievements import achievements_bp
    from .challenges import challenges_bp
    from .stories import stories_bp
    from .moments import moments_bp
    from .clubs import clubs_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(friends_bp)
    app.register_blueprint(chat_bp)
    app.register_blueprint(profile_bp)
    app.register_blueprint(statistics_bp)
    app.register_blueprint(routes_bp)
    app.register_blueprint(achievements_bp)
    app.register_blueprint(challenges_bp)
    app.register_blueprint(stories_bp)
    app.register_blueprint(moments_bp)
    app.register_blueprint(clubs_bp)

__all__ = ['register_blueprints']
