import os
from app import app, db, User

def initialize_database():
    """
    在应用上下文中创建数据库表并初始化管理员账户。
    """
    with app.app_context():
        print("Creating all database tables...")
        db.create_all()
        print("Tables created.")

        # 从环境变量获取管理员凭据，提供默认值
        admin_username = os.environ.get('ADMIN_USERNAME', 'admin')
        admin_password = os.environ.get('ADMIN_PASSWORD', 'admin123')

        # 检查管理员用户是否已存在
        if not User.query.filter_by(username=admin_username).first():
            print(f"Admin user '{admin_username}' not found. Creating it...")
            # 创建新用户
            user = User(username=admin_username, password=admin_password)
            db.session.add(user)
            db.session.commit()
            print(f"Default admin user '{admin_username}' created successfully.")
        else:
            print(f"Admin user '{admin_username}' already exists.")

if __name__ == '__main__':
    print("Starting database initialization...")
    initialize_database()
    print("Database initialization finished.")
