using System;

namespace Cyan_Service_Migration.Services
{
    public class ScheduledTaskSettings
    {
        /// <summary>
        /// 任务执行模式
        /// </summary>
        public TaskExecutionMode ExecutionMode { get; set; } = TaskExecutionMode.Daily;

        /// <summary>
        /// 执行时间（适用于每日模式）
        /// </summary>
        public TimeSpan ExecutionTime { get; set; } = new TimeSpan(18, 0, 0); // 默认18:00

        /// <summary>
        /// 执行间隔（适用于间隔模式，单位：分钟）
        /// </summary>
        public int IntervalMinutes { get; set; } = 60; // 默认60分钟

        /// <summary>
        /// 是否启用定时任务
        /// </summary>
        public bool IsEnabled { get; set; } = true;
    }

    /// <summary>
    /// 任务执行模式枚举
    /// </summary>
    public enum TaskExecutionMode
    {
        /// <summary>
        /// 每日固定时间执行
        /// </summary>
        Daily,

        /// <summary>
        /// 按固定间隔执行
        /// </summary>
        Interval,

        /// <summary>
        /// 自定义CRON表达式执行
        /// </summary>
        Cron
    }
}