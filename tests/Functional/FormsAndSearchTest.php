<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\Mime\Email;
use Zitou\Core\Http\JsonPayload;
use Zitou\Module\Editorial\Form\Input\FormInputFactoryInterface;
use Zitou\Module\Editorial\Form\Manager\FormManagerInterface;
use Zitou\Module\Editorial\Post\Input\PostInputFactoryInterface;
use Zitou\Module\Editorial\Post\Manager\PostManagerInterface;
use Zitou\Module\Editorial\PostType\Entity\PostTypeInterface;
use Zitou\Module\Editorial\PostType\Repository\PostTypeRepository;

/**
 * The engine's forms and search served by the site: a visitor sends a form and the team gets the e-mail through
 * the queue, and the search finds an article whatever the accents (the unaccent extension of the migrations).
 */
final class FormsAndSearchTest extends WebTestCase
{
    public function testAVisitorSendsAFormAndTheTeamReceivesTheAnswer(): void
    {
        $client = self::createClient();
        $input = self::getContainer()->get(FormInputFactoryInterface::class)->createFormInput(new JsonPayload([
            'active' => true,
            'notificationEmail' => 'equipe@example.fr',
            'titles' => ['fr' => 'Nous écrire'],
            'slugs' => ['fr' => ''],
            'confirmations' => ['fr' => 'Merci, à très vite.'],
            'fields' => [
                $this->field('email', 'email', 'Votre e-mail', required: true),
                $this->field('message', 'textarea', 'Votre message'),
            ],
        ]));
        self::getContainer()->get(FormManagerInterface::class)->createForm($input);

        $crawler = $client->request('GET', '/forms/nous-ecrire');
        self::assertResponseIsSuccessful();
        self::assertSelectorTextContains('h1', 'Nous écrire');

        $client->submit($crawler->selectButton('Envoyer')->form([
            'fields[email]' => 'camille@example.fr',
            'fields[message]' => 'Une question sur le potager.',
        ]), serverParameters: ['HTTP_REFERER' => 'http://localhost/forms/nous-ecrire']);

        self::assertResponseRedirects('/forms/nous-ecrire?sent=1', 303);
        self::assertEmailCount(1);
        $email = self::getMailerMessage();
        self::assertInstanceOf(Email::class, $email);
        self::assertSame('equipe@example.fr', $email->getTo()[0]->getAddress());
        self::assertStringContainsString('Une question sur le potager.', (string) $email->getHtmlBody());

        $client->followRedirect();
        self::assertSelectorTextContains('main', 'Merci, à très vite.');
    }

    public function testTheSearchFindsAnArticleWhateverTheAccents(): void
    {
        $client = self::createClient();
        $container = self::getContainer();
        $type = $container->get(PostTypeRepository::class)->findOneByIdentifier('article');
        self::assertInstanceOf(PostTypeInterface::class, $type);
        $container->get(PostManagerInterface::class)->create($container->get(PostInputFactoryInterface::class)->createInput(new JsonPayload([
            'typeId' => $type->getId(),
            'status' => 'published',
            'translations' => ['fr' => ['title' => 'Les tomates d’été', 'content' => ['blocks' => []]]],
        ])), null);

        $client->request('GET', '/search?search=ETE');

        self::assertResponseIsSuccessful();
        self::assertSelectorTextContains('main', 'Les tomates d’été');
    }

    /**
     * One field as the form builder sends it.
     *
     * @return array<string, mixed>
     */
    private function field(string $name, string $type, string $label, bool $required = false): array
    {
        return [
            'id' => null,
            'name' => $name,
            'type' => $type,
            'required' => $required,
            'step' => 0,
            'labels' => ['fr' => $label],
            'placeholders' => [],
            'choices' => [],
            'conditions' => [],
            'conditionLogic' => 'all',
        ];
    }
}
