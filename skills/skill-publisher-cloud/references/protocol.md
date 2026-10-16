# 输入与验证

```json
{
  "requestId":"example-skill-v1-first-publish",
  "skill":"example-skill",
  "version":"1.0.0",
  "files":{
    "SKILL.md":"---\nname: example-skill\ndescription: 说明这个 Skill 做什么及何时使用\n---\n这里是执行指导。\n",
    "references/example.md":"这里是完整附件。\n"
  }
}
```

校验工具不需要 requestId；发布与查询工具需要。没有上游模型调用。上传使用既有 skill.vyibc.com 文件服务；服务端不执行传入脚本、不调用 Hub、不调用 Harness。

安装命令支持 codex、claude、agents 三个目标；重复安装会比较本地完整文件，不同内容要求用户先审阅，不覆盖旧目录。安装前可下载ZIP并核对回执SHA256，安装后检查完整附件及Skill发现。

服务只接收专用 Bearer 授权，环境配置为 `MCP_TOKEN`、`UPLOAD_TOKEN` 和独立 `DB`。凭据不进入安装包、回执、日志或工具参数。

卸载只移除 `skill-publisher-cloud` Skill 或其所属插件，以及本次添加的 `vyibc-skill-publisher` 客户端连接；不删除已发布文件、作业历史或其他配置。部署回退与数据保留由服务所有者单独处理。
