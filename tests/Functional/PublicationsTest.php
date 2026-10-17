<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Zitou\Core\Http\JsonPayload;
use Zitou\Module\Editorial\Post\Entity\PostInterface;
use Zitou\Module\Editorial\Post\Input\PostInputFactoryInterface;
use Zitou\Module\Editorial\Post\Manager\PostManagerInterface;
use Zitou\Module\Editorial\PostType\Entity\PostTypeInterface;
use Zitou\Module\Editorial\PostType\Repository\PostTypeRepository;

/**
 * The engine's publications served by the site: an article written through the engine's services shows on its
 * own page, on the home page and in the sitemap, with the site's theme.
 */
final class PublicationsTest extends WebTestCase
{
    public function testAPublishedArticleShowsOnItsPageOnTheHomePageAndInTheSitemap(): void
    {
        $client = self::createClient();
        $this->publishArticle('Bienvenue sur le site', 'Le premier article de ce site.');

        $client->request('GET', '/article/bienvenue-sur-le-site');
        self::assertResponseIsSuccessful();
        self::assertSelectorTextContains('h1', 'Bienvenue sur le site');
        self::assertSelectorTextContains('main', 'Le premier article de ce site.');

        $client->request('GET', '/');
        self::assertResponseIsSuccessful();
        self::assertSelectorTextContains('main', 'Bienvenue sur le site');

        $client->request('GET', '/sitemap.xml');
        self::assertResponseIsSuccessful();
        self::assertStringContainsString('/article/bienvenue-sur-le-site</loc>', (string) $client->getResponse()->getContent());
    }

    public function testADraftStaysOffTheSite(): void
    {
        $client = self::createClient();
        $this->publishArticle('Pas encore prêt', 'Ce texte attend encore.', 'draft');

        $client->request('GET', '/article/pas-encore-pret');

        self::assertResponseStatusCodeSame(404);
    }

    private function publishArticle(string $title, string $text, string $status = 'published'): PostInterface
    {
        $container = self::getContainer();
        $type = $container->get(PostTypeRepository::class)->findOneByIdentifier('article');
        self::assertInstanceOf(PostTypeInterface::class, $type);
        $input = $container->get(PostInputFactoryInterface::class)->createInput(new JsonPayload([
            'typeId' => $type->getId(),
            'status' => $status,
            'translations' => [
                'fr' => [
                    'title' => $title,
                    'content' => ['blocks' => [['type' => 'paragraph', 'data' => ['text' => $text]]]],
                ],
            ],
        ]));

        return $container->get(PostManagerInterface::class)->create($input, null);
    }
}
