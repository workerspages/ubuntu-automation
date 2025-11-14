#!/usr/bin/env python3
"""
Selenium IDE任务执行器
用于执行.side格式的Selenium脚本文件
"""

import sys
import json
import time
import logging
from pathlib import Path
from datetime import datetime
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.action_chains import ActionChains
import requests

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/app/data/executor.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class SeleniumIDEExecutor:
    """Selenium IDE脚本执行器"""
    
    def __init__(self, script_path):
        self.script_path = script_path
        self.driver = None
        self.variables = {}
        
    def setup_driver(self):
        """初始化WebDriver"""
        try:
            options = Options()
            options.add_argument('--no-sandbox')
            options.add_argument('--disable-dev-shm-usage')
            options.set_preference('intl.accept_languages', 'zh-CN')
            
            # 如果需要无头模式
            # options.add_argument('--headless')
            
            self.driver = webdriver.Firefox(options=options)
            self.driver.implicitly_wait(10)
            logger.info("WebDriver初始化成功")
            return True
        except Exception as e:
            logger.error(f"WebDriver初始化失败: {e}")
            return False
    
    def load_script(self):
        """加载Selenium IDE脚本"""
        try:
            with open(self.script_path, 'r', encoding='utf-8') as f:
                script_data = json.load(f)
            logger.info(f"成功加载脚本: {self.script_path}")
            return script_data
        except Exception as e:
            logger.error(f"加载脚本失败: {e}")
            return None
    
    def execute_command(self, command):
        """执行单个命令"""
        cmd = command.get('command', '')
        target = command.get('target', '')
        value = command.get('value', '')
        
        try:
            # 替换变量
            target = self.replace_variables(target)
            value = self.replace_variables(value)
            
            logger.info(f"执行命令: {cmd} | {target} | {value}")
            
            if cmd == 'open':
                self.driver.get(target if target.startswith('http') else f"http://{target}")
            
            elif cmd == 'click':
                element = self.find_element(target)
                element.click()
            
            elif cmd == 'type':
                element = self.find_element(target)
                element.clear()
                element.send_keys(value)
            
            elif cmd == 'sendKeys':
                element = self.find_element(target)
                element.send_keys(value)
            
            elif cmd == 'select':
                from selenium.webdriver.support.select import Select
                element = self.find_element(target)
                select = Select(element)
                select.select_by_visible_text(value)
            
            elif cmd == 'waitForElementVisible':
                WebDriverWait(self.driver, 30).until(
                    EC.visibility_of_element_located(self.parse_locator(target))
                )
            
            elif cmd == 'waitForElementPresent':
                WebDriverWait(self.driver, 30).until(
                    EC.presence_of_element_located(self.parse_locator(target))
                )
            
            elif cmd == 'pause':
                time.sleep(int(value) / 1000)
            
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
                assert element.text == value, f"文本不匹配: 期望 '{value}', 实际 '{element.text}'"
            
            elif cmd == 'assertTitle':
                assert self.driver.title == target, f"标题不匹配: 期望 '{target}', 实际 '{self.driver.title}'"
            
            elif cmd == 'mouseOver':
                element = self.find_element(target)
                ActionChains(self.driver).move_to_element(element).perform()
            
            elif cmd == 'doubleClick':
                element = self.find_element(target)
                ActionChains(self.driver).double_click(element).perform()
            
            elif cmd == 'executeScript':
                self.driver.execute_script(target)
            
            elif cmd == 'refresh':
                self.driver.refresh()
            
            elif cmd == 'close':
                self.driver.close()
            
            else:
                logger.warning(f"未知命令: {cmd}")
            
            return True
            
        except Exception as e:
            logger.error(f"命令执行失败: {cmd} - {e}")
            return False
    
    def find_element(self, target):
        """查找元素"""
        by, value = self.parse_locator(target)
        return self.driver.find_element(by, value)
    
    def parse_locator(self, target):
        """解析定位器"""
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
        """替换变量"""
        if not text:
            return text
        for var_name, var_value in self.variables.items():
            text = text.replace(f'${{{var_name}}}', str(var_value))
        return text
    
    def execute(self):
        """执行完整脚本"""
        start_time = datetime.now()
        
        try:
            # 加载脚本
            script_data = self.load_script()
            if not script_data:
                return False, "脚本加载失败"
            
            # 初始化浏览器
            if not self.setup_driver():
                return False, "浏览器初始化失败"
            
            # 执行测试
            tests = script_data.get('tests', [])
            for test in tests:
                logger.info(f"执行测试: {test.get('name', 'Unnamed')}")
                commands = test.get('commands', [])
                
                for i, command in enumerate(commands):
                    if not self.execute_command(command):
                        error_msg = f"命令执行失败 (第{i+1}条): {command.get('command')}"
                        return False, error_msg
            
            duration = (datetime.now() - start_time).total_seconds()
            logger.info(f"脚本执行成功，耗时: {duration:.2f}秒")
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

def send_telegram_notification(script_name, success, message, bot_token, chat_id):
    """发送Telegram通知"""
    if not bot_token or not chat_id:
        return
    
    status_emoji = '✅' if success else '❌'
    status_text = '成功' if success else '失败'
    
    html_message = f"""
<b>{status_emoji} Selenium任务执行通知</b>

<b>脚本名称:</b> {script_name}
<b>执行状态:</b> {status_text}
<b>执行时间:</b> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
<b>详细信息:</b> {message}
"""
    
    url = f'https://api.telegram.org/bot{bot_token}/sendMessage'
    data = {
        'chat_id': chat_id,
        'text': html_message,
        'parse_mode': 'HTML'
    }
    
    try:
        response = requests.post(url, data=data, timeout=10)
        if response.status_code == 200:
            logger.info("Telegram通知发送成功")
        else:
            logger.warning(f"Telegram通知发送失败: {response.status_code}")
    except Exception as e:
        logger.error(f"发送Telegram通知异常: {e}")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("用法: python3 task_executor.py <script_path> [bot_token] [chat_id]")
        sys.exit(1)
    
    script_path = sys.argv[1]
    bot_token = sys.argv[2] if len(sys.argv) > 2 else None
    chat_id = sys.argv[3] if len(sys.argv) > 3 else None
    
    # 执行脚本
    executor = SeleniumIDEExecutor(script_path)
    success, message = executor.execute()
    
    # 发送通知
    if bot_token and chat_id:
        script_name = Path(script_path).name
        send_telegram_notification(script_name, success, message, bot_token, chat_id)
    
    # 返回执行结果
    sys.exit(0 if success else 1)
