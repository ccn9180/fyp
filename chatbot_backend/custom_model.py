import torch
import torch.nn as nn


class CustomNeuralNet(nn.Module):
    def __init__(
        self,
        vocab_size: int,
        embedding_dim: int,
        hidden_size: int,
        num_classes: int,
        pad_idx: int = 0,
        num_layers: int = 1,
        dropout: float = 0.3,
    ):
        super(CustomNeuralNet, self).__init__()

        self.embedding = nn.Embedding(
            num_embeddings=vocab_size,
            embedding_dim=embedding_dim,
            padding_idx=pad_idx
        )

        # NEW: embed dropout — regularises before LSTM sees input
        self.embed_dropout = nn.Dropout(dropout)

        self.bilstm = nn.LSTM(
            input_size=embedding_dim,
            hidden_size=hidden_size,
            num_layers=num_layers,
            batch_first=True,
            bidirectional=True,
            dropout=dropout if num_layers > 1 else 0.0
        )

        self.attention = nn.Linear(hidden_size * 2, 1)

        # explicit post-LSTM dropout (works regardless of num_layers)
        self.output_dropout = nn.Dropout(dropout)

        self.fc = nn.Linear(hidden_size * 2, num_classes)

    def forward(self, x):
        embedded = self.embedding(x)            # [B, T, E]
        embedded = self.embed_dropout(embedded)  # NEW: dropout on embeddings

        lstm_out, _ = self.bilstm(embedded)     # [B, T, 2H]

        attn_scores = self.attention(lstm_out).squeeze(-1)  # [B, T]
        attn_weights = torch.softmax(attn_scores, dim=1)    # [B, T]

        context = torch.sum(
            lstm_out * attn_weights.unsqueeze(-1), dim=1
        )                                        # [B, 2H]

        context = self.output_dropout(context)   # renamed from self.dropout

        out = self.fc(context)                   # [B, C]
        return out
