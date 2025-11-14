from flask import Flask, render_template, request, redirect, url_for, jsonify, flash
from flask_login import LoginManager, UserMixin, login_user, logout_user, login_required, current_user
from flask_sqlalchemy import SQLAlchemy
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from datetime import datetime
import os
import json
import requests
from pathlib import Path
import subprocess
import logging
import time
import random
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.action_chains import ActionChains

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'your-secret-key-change-this')
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('SQLALCHEMY_DATABASE_URI', 'sqlite:////app/data/tasks.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

scheduler = BackgroundScheduler()
scheduler.start()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password = db.Column(db.String(120), nullable=False)

class Task(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(200), nullable=False)
    script_path = db.Column(db.String(500), nullable=False)
    cron_expression = db.Column(db.String(100), nullable=False)
    enabled = db.Column(db.Boolean, default=True)
    last_run = db.Column(db.DateTime)
    last_status = db.Column(db.String(50))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

@login_manager.user_loader
def load_user(user_id):
    return db.session.get(User, int(user_id))

# SeleniumIDEExecutor 类拷贝自你之前的完整代码，保持一致
class SeleniumIDEExecutor:
    def __init__(self, script_path):
        self.script_path = script_path
        self.driver = None
        self.variables = {}
        self.base_url = ''

    def setup_driver(self):
        try:
            os.environ['DISPLAY'] = ':1'
            options = Options()
            options.add_argument('--no-sandbox')
            options.add_argument('--disable-dev-shm-usage')
            options.set_preference('intl.accept_languages', 'zh-CN')
            options.set_preference('dom.webdriver.enabled', False)
            options.set_preference('useAutomationExtension', False)
            options.set_preference('general.useragent.override', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
            self.driver = webdriver.Firefox(options=options)
            self.driver.implicitly_wait(10)
            self.driver.execute_script("""
                Object.defineProperty(navigator, 'webdriver', {get: () => undefined});
                window.navigator.chrome = {runtime: {}};
                Object.defineProperty(navigator, 'plugins', {get: () => [1, 2, 3, 4, 5]});
                Object.defineProperty(navigator, 'languages', {get: () => ['zh-CN', 'zh', 'en']});
            """)
            logger.info("WebDriver初始化成功（可视化模式 + 反检测）")
            return True
        except Exception as e:
            logger.error(f"WebDriver初始化失败: {e}")
            return False

    def load_script(self):
        try:
            with open(self.script_path, 'r', encoding='utf-8') as f:
                script_data = json.load(f)
            if 'url' in script_data:
                self.base_url = script_data['url']
                logger.info(f"读取到 base URL: {self.base_url}")
            logger.info(f"成功加载脚本: {self.script_path}")
            return script_data
        except Exception as e:
            logger.error(f"加载脚本失败: {e}")
            return None

    def human_delay(self, min_delay=0.5, max_delay=2.0):
        time.sleep(random.uniform(min_delay, max_delay))

    def execute_command(self, command):
        cmd = command.get('command', '')
        target = self.replace_variables(command.get('target', ''))
        value = self.replace_variables(command.get('value', ''))
        try:
            self.human_delay()
            logger.info(f"执行命令: {cmd} | {target} | {value}")
            if cmd == 'open':
                if target.startswith('http'):
                    url = target
                elif target.startswith('/'):
                    url = (self.base_url.rstrip('/') if self.base_url else 'https://www.baidu.com') + target
                else:
                    url = f"http://{target}"
                self.driver.get(url)
            elif cmd == 'click':
                element = self.find_element(target)
                self.driver.execute_script("arguments[0].scrollIntoView({behavior: 'smooth', block: 'center'});", element)
                time.sleep(0.5)
                ActionChains(self.driver).move_to_element(element).pause(0.3).click().perform()
            elif cmd == 'type':
                element = self.find_element(target)
                element.clear()
                time.sleep(0.2)
                for c in value:
                    element.send_keys(c)
                    time.sleep(random.uniform(0.05, 0.15))
            elif cmd == 'sendKeys':
                element = self.find_element(target)
                for c in value:
                    element.send_keys(c)
                    time.sleep(random.uniform(0.05, 0.15))
            elif cmd == 'select':
                from selenium.webdriver.support.select import Select
                element = self.find_element(target)
                Select(element).select_by_visible_text(value)
            elif cmd == 'waitForElementVisible':
                WebDriverWait(self.driver, 30).until(EC.visibility_of_element_located(self.parse_locator(target)))
            elif cmd == 'waitForElementPresent':
                WebDriverWait(self.driver, 30).until(EC.presence_of_element_located(self.parse_locator(target)))
            elif cmd == 'pause':
                time.sleep(int(value)/1000)
            elif cmd == 'store':
                self.variables[value] = target
            elif cmd == 'storeText':
                element = self.find_element(target)
                self.variables[value] = element.text
            elif cmd == 'storeValue':
                element = self.find_element(target)
                self.variables[value] = element.get_attribute('value')
            elif cmd == 'assertText':
                element = self.find_element(target)
                assert element.text == value, f"文本不匹配:期望'{value}',实际'{element.text}'"
            elif cmd == 'assertTitle':
                assert self.driver.title == target, f"标题不匹配:期望'{target}',实际'{self.driver.title}'"
            elif cmd == 'mouseOver':
                element = self.find_element(target)
                ActionChains(self.driver).move_to_element(element).perform()
            elif cmd == 'doubleClick':
                element = self.find_element(target)
                ActionChains(self.driver).double_click(element).perform()
            elif cmd == 'executeScript' or cmd == 'runScript':
                self.driver.execute_script(target)
            elif cmd == 'refresh':
                self.driver.refresh()
            elif cmd == 'close':
                self.driver.close()
            elif cmd == 'setWindowSize':
                sizes = value.split('x')
                self.driver.set_window_size(int(sizes[0]), int(sizes[1]))
            else:
                logger.warning(f"未知命令: {cmd}")
            return True
        except Exception as e:
            logger.error(f"命令执行失败: {cmd} - {e}")
            return False

    def find_element(self, target):
        by, value = self.parse_locator(target)
        return self.driver.find_element(by, value)

    def parse_locator(self, target):
        if target.startswith('id='):
            return (By.ID, target[3:])
        elif target.startswith('name='):
            return (By.NAME, target[5:])
        elif target.startswith('css='):
            return (By.CSS_SELECTOR, target[4:])
        elif target.startswith('xpath='):
            return (By.XPATH, target[6:])
        elif target.startswith('linkText='):
            return (By.LINK_TEXT, target[9:])
        elif target.startswith('//'):
            return (By.XPATH, target)
        else:
            return (By.CSS_SELECTOR, target)

    def replace_variables(self, text):
        if not text:
            return text
        for var, val in self.variables.items():
            text = text.replace(f"${{{var}}}", str(val))
        return text

    def execute(self):
        start_time = datetime.now()
        try:
            script_data = self.load_script()
            if not script_data:
                return False, "脚本加载失败"
            if not self.setup_driver():
                return False, "浏览器初始化失败"
            tests = script_data.get('tests', [])
            for test in tests:
                logger.info(f"执行测试: {test.get('name', 'Unnamed')}")
                for i, command in enumerate(test.get('commands', [])):
                    if not self.execute_command(command):
                        return False, f"命令执行失败(第{i+1}条): {command.get('command')}"
            logger.info("任务执行完成，浏览器将在10秒后关闭")
            time.sleep(10)
            duration = (datetime.now() - start_time).total_seconds()
            logger.info(f"脚本执行成功，耗时:{duration:.2f}秒")
            return True, f"执行成功，耗时{duration:.2f}秒"
        except Exception as e:
            logger.error(f"脚本执行异常: {e}")
            return False, str(e)
        finally:
            if self.driver:
                try:
                    self.driver.quit()
                except:
                    pass

def execute_selenium_script(task_id):
    with app.app_context():
        task = db.session.get(Task, task_id)
        if not task:
            return False
        executor = SeleniumIDEExecutor(task.script_path)
        success, message = executor.execute()
        # 此处可以添加记录日志、更新任务状态
        return success

def execute_actiona_script(script_path):
    try:
        result = subprocess.run(
            ['/opt/actiona/actiona.AppImage', '-s', script_path],
            capture_output=True,
            text=True,
            timeout=300
        )
        if result.returncode == 0:
            logger.info("Actiona脚本执行成功")
            return True
        else:
            logger.error(f"Actiona脚本执行失败: {result.stderr}")
            return False
    except Exception as e:
        logger.error(f"执行Actiona脚本异常: {e}")
        return False

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        admin_username = os.environ.get('ADMIN_USERNAME', 'admin')
        admin_password = os.environ.get('ADMIN_PASSWORD', 'admin123')
        if not User.query.filter_by(username=admin_username).first():
            user = User(username=admin_username, password=admin_password)
            db.session.add(user)
            db.session.commit()
            print(f'已创建默认管理员账号: {admin_username}')
        tasks = Task.query.filter_by(enabled=True).all()
        for task in tasks:
            try:
                schedule_task(task)
                print(f'已加载任务: {task.name}')
            except Exception as e:
                print(f'加载任务失败 {task.name}: {e}')
    print('='*50)
    print('Selenium 自动化管理平台已启动')
    print('Web 界面: http://0.0.0.0:5000')
    print(f'默认管理员: {admin_username}')
    print('='*50)
    app.run(host='0.0.0.0', port=5000, debug=False)
