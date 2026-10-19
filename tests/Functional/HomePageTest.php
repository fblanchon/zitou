<?php

namespace App\Tests\Functional;

use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;

final class HomePageTest extends WebTestCase
{
    public function testTheHomePageIsJoyful(): void
    {
        $client = self::createClient();
        $client->request('GET', '/');

        self::assertResponseIsSuccessful();
        self::assertSelectorExists('html[lang="fr"]');
        self::assertPageTitleSame('zitou');
        self::assertSelectorTextContains('h1', 'zitou');
        self::assertSelectorExists('.zitou-home .sky');
        self::assertSelectorTextContains('.zitou-home .lede', 'Un petit coin du web qui fait sourire');
        self::assertSelectorTextContains('.zitou-home .joy-label', 'Le petit bonheur du jour');
        self::assertSelectorTextContains('.zitou-home .joy-quote', 'Une crêpe ratée reste une crêpe.');
        self::assertSelectorExists('.zitou-home .polaroid img[src="/accueil/images/crepes.webp"]');
        self::assertSelectorExists('link[rel="stylesheet"][href="/accueil/accueil.css"]');
        self::assertSelectorExists('script[src="/accueil/accueil.js"][defer]');
        self::assertSelectorTextNotContains('.zitou-home', 'fait main');
    }

    public function testEveryThoughtHasItsTextsAndAPictureThatExists(): void
    {
        $client = self::createClient();
        $crawler = $client->request('GET', '/');

        $thoughts = json_decode((string) $crawler->filter('.zitou-home')->attr('data-thoughts'), true, flags: \JSON_THROW_ON_ERROR);
        self::assertIsArray($thoughts);
        self::assertCount(16, $thoughts);
        $projectDirectory = self::getContainer()->getParameter('kernel.project_dir');
        self::assertIsString($projectDirectory);
        foreach ($thoughts as $thought) {
            self::assertIsArray($thought);
            foreach (['text', 'caption', 'alt'] as $key) {
                self::assertIsString($thought[$key]);
                self::assertStringStartsNotWith('site.home.', $thought[$key], 'A text of the home page has no translation.');
            }
            self::assertIsString($thought['image']);
            self::assertFileExists($projectDirectory.'/public'.$thought['image']);
        }
        self::assertCount(16, $crawler->filter('.zitou-home .thanks li a[href^="https://www.pexels.com/photo/"]'));
    }
}
