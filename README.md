# Premier Defi Formation Ropsten
Contrat de vote

Explication des fonctionnalités:


Deux events rajoutés:
    - ProposalDraw: Annoncer une égalité entre deux proposals
    - VoterUnregistered: Signaler qu'un voter a été unregistered.

voterAddresses[] - Garde une liste des addresses des voteurs pour avoir la possibilité de les récupérer et les supprimer à la fin d'une séance de vote.


changeVote(proposalId) - En cas d'erreur de l'utilisateur, il peut changer son vote.

restartVotingSession(removeVoters) - Recommence la session de vote au début, avec ou sans les mêmes Voters, au choix.
    - Reset le status à "Registering voters"
    - Reinitialize la liste de proposals
    - Annule les votes de la session précédente
    - Supprime le vainqueur de la séance précédente
    - Supprime voterAddreses si l'utilisateur le souhaite (bool removeVoters)    
    

unregisterVoter(voterAddress) - En cas d'erreur de l'adminisatrateur, celui ci peut toujours enlever un Voter ajouté plus tot dans la séance (seulement en début de séance).
    - Il peut toujours être rajouté après si l'admnistrateur le décide.
    
setWinner() - Définie la proposal qui remporte le vote, appelé au moment où la session rentre dans la phase VotesTallied. 
getWinner() - Retourn l'Id de la proposal qui remporte le vote.

handleDraw(id1, id2) - Départage deux proposals avec le même nombre de votes. Retourne la plus ancienne proposal ajoutée pour l'instant.
