# ❄️ NixOS Configuration: Infrastructure as Code (IaC)

[![NixOS Version](https://img.shields.io/badge/NixOS-25.05%20(Warbler)-blue?logo=nixos&logoColor=white)](https://nixos.org)
[![Platform](https://img.shields.io/badge/Platform-Linux-orange?logo=linux&logoColor=white)](https://kernel.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

## 📌 Objetivo do Projeto
Este repositório centraliza a especificação completa, declarativa e reprodutível do meu ambiente de desenvolvimento. Utilizando o ecossistema Nix, este projeto aplica conceitos consolidados de **Engenharia de Software** e **Infraestrutura como Código (IaC)** para garantir que todo o sistema operacional, ferramentas de build, configurações de editores e variáveis de ambiente possam ser reconstruídos do zero, de forma idêntica, em qualquer máquina, em poucos minutos.

## ⚙️ Conceitos de Engenharia de Software Aplicados

### 1. Reprodutibilidade e Imutabilidade
Diferente das distribuições Linux tradicionais baseadas em mutação de estado imperativa (`apt`, `pacman`), este ambiente é construído a partir de funções puras. O estado do sistema é derivado estritamente do código contido neste repositório, mitigando completamente o problema de desvio de configuração (*configuration drift*).

### 2. Separação de Responsabilidades (Separation of Concerns)
O projeto é arquitetado em duas camadas lógico-operacionais independentes:
* **System Space (`configuration.nix`):** Gerencia o hardware, drivers, serviços essenciais do sistema (daemons, Docker, partições) e políticas globais de segurança.
* **User Space (`Home Manager`):** Gerenciamento isolado das ferramentas do usuário (`dotfiles`), configurações de shell, linters, ambientes de execução (Node.js, Python) e utilitários CLI, sem poluir o escopo raiz.

### 3. Gerenciamento Declarativo de Dependências
Todas as ferramentas de desenvolvimento necessárias para o dia a dia estão versionadas sob controle de versão (Git). O ambiente de desenvolvimento se comporta exatamente como um projeto de software, onde atualizações de ferramentas passam por code review e testes antes do deploy (`nixos-rebuild`).

---

## 📂 Arquitetura e Estrutura do Repositório

```text
├── dotfiles                       # Configurações declarativas de escopo do usuário (Dotfiles e Aplicações)
├── hosts/macbookpro2012           # Diferentes hosts no sistema e suas configurações individuais
    ├── configuration.nix          # Configuração centralizada a nível de sistema (Root)
    └── hardware-configuration.nix # Mapeamento físico e drivers gerados via hardware scan
└── modules/                       # Configurações modulares e isoladas do ambiente
    ├── system/                    # Módulos do sistema (Drivers, NetworkManager, Serviços de Background)
    └── home/                      # Configurações para o rebuild correto do sistemas atraves de imports
