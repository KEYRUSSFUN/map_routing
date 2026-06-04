def register_blueprints(app):
    from .auth import auth_bp
    from .friends import friends_bp
    from .chat import chat_bp
    from .profile import profile_bp
    from .statistics import statistics_bp
    from .routes_bp import routes_bp
    from .groups import groups_bp 

    app.register_blueprint(auth_bp)
    app.register_blueprint(friends_bp)
    app.register_blueprint(chat_bp)
    app.register_blueprint(profile_bp)
    app.register_blueprint(statistics_bp)
    app.register_blueprint(routes_bp)
    app.register_blueprint(groups_bp) 

__all__ = ['register_blueprints']
