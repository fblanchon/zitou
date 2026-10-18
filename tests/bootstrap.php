<?php

declare(strict_types=1);

use App\Kernel;
use Symfony\Bundle\FrameworkBundle\Console\Application;
use Symfony\Component\Console\Input\ArrayInput;
use Symfony\Component\Console\Output\BufferedOutput;
use Symfony\Component\Dotenv\Dotenv;

require __DIR__.'/../vendor/autoload.php';

new Dotenv()->bootEnv(__DIR__.'/../.env');

if ($_SERVER['APP_DEBUG']) {
    umask(0000);
}

// A fresh test database for every run, created from the entity schema of the engine and the site rather than
// by replaying the migrations, whose order may break on an empty database (CI checks them apart).
// Then the declared settings and the languages. Each test runs in a transaction that DAMADoctrineTestBundle
// rolls back.
(static function (): void {
    $kernel = new Kernel('test', false);
    $kernel->boot();
    $application = new Application($kernel);
    $application->setAutoExit(false);
    $commands = [
        ['command' => 'doctrine:database:drop', '--force' => true, '--if-exists' => true],
        ['command' => 'doctrine:database:create'],
        // The search compares words without accents; the migrations create it on a real site.
        ['command' => 'dbal:run-sql', 'sql' => 'CREATE EXTENSION IF NOT EXISTS unaccent'],
        ['command' => 'doctrine:schema:create'],
        ['command' => 'zitou:application-parameter'],
        ['command' => 'zitou:install'],
    ];
    foreach ($commands as $command) {
        $output = new BufferedOutput();
        $input = new ArrayInput($command);
        $input->setInteractive(false);
        if (0 !== $application->run($input, $output)) {
            throw new RuntimeException(sprintf("Test database: \"%s\" failed.\n%s", $command['command'], $output->fetch()));
        }
    }
    $kernel->shutdown();
})();
