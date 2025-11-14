let currentTaskId = null;

// 打开添加模态框
function openAddModal() {
    currentTaskId = null;
    document.getElementById('modalTitle').textContent = '添加任务';
    document.getElementById('taskForm').reset();
    document.getElementById('taskId').value = '';
    document.getElementById('taskModal').style.display = 'block';
}

// 编辑任务
function editTask(taskId) {
    currentTaskId = taskId;
    document.getElementById('modalTitle').textContent = '编辑任务';
    
    // 获取任务详情
    fetch(`/api/tasks/${taskId}`)
        .then(response => response.json())
        .then(task => {
            document.getElementById('taskId').value = task.id;
            document.getElementById('taskName').value = task.name;
            document.getElementById('scriptPath').value = task.script_path;
            document.getElementById('cronExpression').value = task.cron_expression;
            document.getElementById('taskModal').style.display = 'block';
        })
        .catch(error => {
            alert('获取任务详情失败: ' + error);
        });
}

// 保存任务
function saveTask(event) {
    event.preventDefault();
    
    const taskId = document.getElementById('taskId').value;
    const data = {
        name: document.getElementById('taskName').value,
        script_path: document.getElementById('scriptPath').value,
        cron_expression: document.getElementById('cronExpression').value,
        enabled: true
    };
    
    const url = taskId ? `/api/tasks/${taskId}` : '/api/tasks';
    const method = taskId ? 'PUT' : 'POST';
    
    fetch(url, {
        method: method,
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    })
    .then(response => response.json())
    .then(result => {
        if (result.success) {
            closeModal();
            location.reload();
        } else {
            alert('保存失败: ' + (result.error || '未知错误'));
        }
    })
    .catch(error => {
        alert('保存失败: ' + error);
    });
}

// 立即执行任务
function runTaskNow(taskId) {
    if (!confirm('确定立即执行此任务吗？')) {
        return;
    }
    
    fetch(`/api/tasks/${taskId}/run`, {
        method: 'POST'
    })
    .then(response => response.json())
    .then(result => {
        if (result.success) {
            alert('任务已开始执行，请在VNC窗口查看执行过程');
        } else {
            alert('执行失败: ' + (result.error || '未知错误'));
        }
    })
    .catch(error => {
        alert('执行失败: ' + error);
    });
}

// 删除任务
function deleteTask(taskId) {
    if (!confirm('确定删除此任务吗？')) {
        return;
    }
    
    fetch(`/api/tasks/${taskId}`, {
        method: 'DELETE'
    })
    .then(response => response.json())
    .then(result => {
        if (result.success) {
            location.reload();
        } else {
            alert('删除失败: ' + (result.error || '未知错误'));
        }
    })
    .catch(error => {
        alert('删除失败: ' + error);
    });
}

// 设置 Cron 表达式
function setCron(expression) {
    document.getElementById('cronExpression').value = expression;
    updateCronHelp(expression);
}

// 更新 Cron 说明
function updateCronHelp(expression) {
    const helpText = document.getElementById('cronHelp');
    const descriptions = {
        '*/5 * * * *': '每5分钟执行一次',
        '0 * * * *': '每小时整点执行',
        '0 9 * * *': '每天上午9点执行',
        '0 9,12,18 * * *': '每天上午9/12/18点执行',
        '0 0 * * 1': '每周一午夜执行',
        '0 0 * * *': '每天午夜执行',
        '0 12 * * *': '每天中午12点执行'
    };
    helpText.textContent = descriptions[expression] || '自定义 Cron 表达式';
}

// 关闭模态框
function closeModal() {
    document.getElementById('taskModal').style.display = 'none';
    currentTaskId = null;
}

// 点击模态框外部关闭
window.onclick = function(event) {
    const modal = document.getElementById('taskModal');
    if (event.target === modal) {
        closeModal();
    }
}

// Cron 表达式输入时更新说明
document.addEventListener('DOMContentLoaded', function() {
    const cronInput = document.getElementById('cronExpression');
    if (cronInput) {
        cronInput.addEventListener('input', function() {
            updateCronHelp(this.value);
        });
    }
});
