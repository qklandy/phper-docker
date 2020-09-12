<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

echo '<h2 style="text-align: center;">微拍堂-后端五组-docker环境</h1>';
echo '<h3>版本信息</h2>';

echo '<ul style="font-size:13px">';
echo '<li>PHP版本：', PHP_VERSION, '</li>';
echo '<li>Nginx版本：', $_SERVER['SERVER_SOFTWARE'], '</li>';
echo '<li>MySQL服务器版本：', getMysqlVersion(), '</li>';
echo '<li>Redis服务器版本：', getRedisVersion(), '</li>';
echo '<li>MongoDB服务器版本：', getMongoVersion(), '</li>';
echo '</ul>';

echo '<h3>已安装扩展</h2>';
printExtensions();


/**
 * 获取MySQL版本
 */
function getMysqlVersion()
{
    if (extension_loaded('PDO_MYSQL')) {
        try {
            $dbh = new PDO('mysql:host=172.10.1.4;dbname=mysql', 'root', '123456');
            $sth = $dbh->query('SELECT VERSION() as version');
            $info = $sth->fetch();
        } catch (PDOException $e) {
            return $e->getMessage();
        }
        return $info['version'];
    } else {
        return 'PDO_MYSQL 扩展未安装 ×';
    }

}

/**
 * 获取Redis版本
 */
function getRedisVersion()
{
    if (extension_loaded('redis')) {
        try {
            $redis = new Redis();
            $redis->connect('172.10.1.6', 6379);
            $info = $redis->info();
            return $info['redis_version'];
        } catch (Exception $e) {
            return $e->getMessage();
        }
    } else {
        return 'Redis 扩展未安装 ×';
    }
}

/**
 * 获取MongoDB版本
 */
function getMongoVersion()
{
    if (extension_loaded('mongodb')) {
        try {
            $manager = new MongoDB\Driver\Manager('mongodb://root:123456@172.10.1.11:27017');
            $command = new MongoDB\Driver\Command(['serverStatus'=>true]);

            $cursor = $manager->executeCommand('admin', $command);

            return $cursor->toArray()[0]->version;
        } catch (Exception $e) {
            return $e->getMessage();
        }
    } else {
        return 'MongoDB 扩展未安装 ×';
    }
}

/**
 * 获取已安装扩展列表
 */
function printExtensions()
{
    echo '<ul style="font-size:13px">';
    foreach (get_loaded_extensions() as $i => $name) {
        echo "<li>", $name, '=', phpversion($name), '</li>';
    }
    echo '</ul>';
}

