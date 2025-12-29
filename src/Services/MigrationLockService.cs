using System;

namespace Cyan_Service_Migration.Services
{
    public class MigrationLockService
    {
        private bool _isMigrationRunning = false;
        private string _currentOperationId = string.Empty;
        private string _currentClientIp = string.Empty;
        private DateTime _operationStartTime;
        private TaskCompletionSource<bool> _migrationCompletionSource;

        /// <summary>
        /// 异步等待迁移完成
        /// </summary>
        public async Task WaitForCompletionAsync(CancellationToken cancellationToken = default)
        {
            if (!_isMigrationRunning)
                return;

            using (cancellationToken.Register(() => _migrationCompletionSource?.TrySetCanceled()))
            {
                await _migrationCompletionSource.Task;
            }
        }

        /// <summary>
        /// 标记迁移操作完成
        /// </summary>
        public void MarkAsCompleted()
        {
            if (_isMigrationRunning)
            {
                _migrationCompletionSource?.TrySetResult(true);
                ReleaseLock();
            }
        }

        // 公共构造函数用于依赖注入
        public MigrationLockService() { }

        /// <summary>
        /// 尝试获取迁移锁
        /// </summary>
        /// <param name="operationId">新操作ID</param>
        /// <param name="clientIp">客户端IP</param>
        /// <returns>是否成功获取锁</returns>
        public bool TryAcquireLock(string operationId, string clientIp)
        {
            if (_isMigrationRunning)
            {
                return false;
            }

            _isMigrationRunning = true;
            _currentOperationId = operationId;
            _currentClientIp = clientIp;
            _operationStartTime = DateTime.Now;
            _migrationCompletionSource = new TaskCompletionSource<bool>();
            return true;
        }

        /// <summary>
        /// 释放迁移锁
        /// </summary>
        public void ReleaseLock()
        {
            _isMigrationRunning = false;
            _currentOperationId = string.Empty;
            _currentClientIp = string.Empty;
        }

        /// <summary>
        /// 获取当前锁定状态信息
        /// </summary>
        /// <param name="operationId">当前操作ID</param>
        /// <param name="clientIp">当前客户端IP</param>
        /// <param name="elapsedTime">已运行时间</param>
        /// <returns>是否有锁定</returns>
        public bool GetCurrentLockStatus(out string operationId, out string clientIp, out TimeSpan elapsedTime)
        {
            operationId = _currentOperationId;
            clientIp = _currentClientIp;
            elapsedTime = _isMigrationRunning ? DateTime.Now - _operationStartTime : TimeSpan.Zero;
            return _isMigrationRunning;
        }
    }
}