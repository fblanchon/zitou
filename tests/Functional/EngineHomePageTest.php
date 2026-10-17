<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Zitou\Module\Configuration\Theme\Input\ThemeCreateInput;
use Zitou\Module\Configuration\Theme\Manager\ThemeManagerInterface;

final class EngineHomePageTest extends WebTestCase
{
    public function testSiteServesTheThemedHomePageWithItsBuiltAssets(): void
    {
        $client = self::createClient();
        $crawler = $client->request('GET', '/');

        self::assertResponseIsSuccessful();
        self::assertSelectorTextContains('h1', 'zitou');
        self::assertSelectorTextContains('footer', 'zitou');
        self::assertSelectorNotExists('body.zitou-theme-zitou');
        self::assertCount(1, $crawler->filter('script[src^="/build/"]'));
        self::assertStringContainsString('--zitou-primary-600:', (string) $client->getResponse()->getContent());
    }

    public function testTheZitouThemeDressesThePagesOnceActive(): void
    {
        $client = self::createClient();
        $manager = self::getContainer()->get(ThemeManagerInterface::class);
        $input = new ThemeCreateInput();
        $input->identifier = 'zitou';
        $input->name = 'zitou';
        $manager->activate($manager->create($input));

        $client->request('GET', '/');

        self::assertResponseIsSuccessful();
        self::assertSelectorTextContains('h1', 'zitou');
        self::assertSelectorExists('body.zitou-site.zitou-theme-zitou');
    }

    public function testSiteServesTheEngineAdminBehindItsSignInPage(): void
    {
        $client = self::createClient();

        $client->request('GET', '/suite');
        self::assertResponseRedirects('/suite/platform/login');

        $client->followRedirect();
        self::assertResponseIsSuccessful();
        self::assertSelectorExists('[data-symfony--ux-vue--vue-component-value="Platform/admin/auth/LoginForm"]');
    }
}
